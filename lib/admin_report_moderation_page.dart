import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/chiplux_palette.dart';
import 'services/profile_service.dart';
import 'services/comment_service.dart';
import 'services/tmdb_service.dart';
import 'comments_page.dart';
import 'main.dart' show PublicProfilePage;

/// Developer-only report queue. Server RPCs independently enforce access.
/// Feature suggestions remain in the original AdminModerationPage.
class AdminReportModerationPage extends StatefulWidget {
  const AdminReportModerationPage({super.key});

  @override
  State<AdminReportModerationPage> createState() => _AdminReportModerationPageState();
}

class _AdminReportModerationPageState extends State<AdminReportModerationPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _cases = [];
  bool _loading = true;
  bool _busy = false;
  bool _showResolved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!ProfileService.instance.isDeveloper) {
      if (mounted) setState(() { _loading = false; _error = 'Developer access only.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final allowed = await _client.rpc('chiplux_moderation_is_admin');
      if (allowed != true) throw StateError('This account is not an authorized moderator.');
      final response = await _client.rpc('chiplux_moderation_list_cases',
        params: {'p_show_resolved': _showResolved});
      if (!mounted) return;
      setState(() {
        _cases = response is List
            ? response.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  Map<String, dynamic> _snap(Map<String, dynamic> c) {
    final raw = c['target_snapshot'];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  String _s(dynamic value) => value?.toString() ?? '';

  Future<void> _openTarget(Map<String, dynamic> c) async {
    final kind = _s(c['target_kind']);
    final snap = _snap(c);
    final targetId = _s(c['target_id']);
    if (kind == 'user') {
      final userId = _s(c['target_user_id']);
      if (userId.isNotEmpty) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PublicProfilePage(userId: userId)));
      }
      return;
    }
    final isMusic = kind == 'music_comment';
    final mediaType = isMusic ? 'music_album' : _s(snap['media_type']);
    final tmdbId = int.tryParse(_s(snap['tmdb_id'])) ?? 0;
    final albumId = _s(snap['album_id']);
    final season = int.tryParse(_s(snap['season_number']));
    final episode = int.tryParse(_s(snap['episode_number']));
    if ((isMusic && albumId.isEmpty) || (!isMusic && (tmdbId == 0 || mediaType.isEmpty))) {
      _message('Original link unavailable. The preserved comment text is shown in this case.');
      return;
    }
    // Normal discussion screens require having watched/listened to a title.
    // The moderation case always retains a server-authorized snapshot below.
    try {
      final accessible = isMusic
          ? await CommentService.instance.canAccessMusicAlbumComments(albumId: albumId)
          : await CommentService.instance.canAccess(mediaType: mediaType,tmdbId: tmdbId,
              seasonNumber: season,episodeNumber: episode);
      if (!accessible) {
        if (!mounted) return;
        await _showOriginal(c, 'This discussion is normally locked until watched/listened. The moderator evidence is still available:');
        return;
      }
      String title = isMusic ? 'Album discussion' : 'Reported discussion';
      if (!isMusic) {
        try {
          final details = await TmdbService().getDetails(tmdbId,mediaType=='episode'?'tv':mediaType);
          title = _s(details['title'] ?? details['name']);
          if (title.isEmpty) title='Reported discussion';
        } catch (_) { /* The route can still open with a fallback title. */ }
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommentsPage(
        mediaType: mediaType, tmdbId: tmdbId, musicAlbumId: isMusic ? albumId : null,
        seasonNumber: season, episodeNumber: episode,
        targetCommentId: targetId, title: title,
        onProfileTap: (userId) async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PublicProfilePage(userId: userId)));
        },
      )));
    } catch (e) {
      if (!mounted) return;
      await _showOriginal(c, 'Unable to open discussion ($e). Preserved moderation evidence:');
    }
  }

  Future<void> _showOriginal(Map<String, dynamic> c, String heading) async {
    final snap = _snap(c);
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Original comment'),
      content: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(heading), const SizedBox(height:12),
          SelectableText(_s(snap['body']).isNotEmpty ? _s(snap['body']) : '[Comment unavailable]'),
          const SizedBox(height:12), Text('Comment ID: ${_s(c['target_id'])}',
            style: const TextStyle(fontSize:11,color:Colors.white54))],
      )),
      actions: [TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))],
    ));
  }

  void _message(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _act(Map<String, dynamic> c, String action) async {
    if (_busy) return;
    final label = {
      'dismiss': 'Dismiss case',
      'remove_comment': 'Permanently remove comment',
      'warn': 'Warn user',
      'suspend_24h': 'Suspend user for 24 hours',
      'suspend_7d': 'Suspend user for 7 days',
      'ban': 'Ban user',
    }[action] ?? action;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(context:context,builder:(ctx)=> AlertDialog(
      title: Text(label),
      content: Column(mainAxisSize:MainAxisSize.min,children:[
        Text(action=='remove_comment'
          ? 'This removes the comment from Chiplux. Its snapshot remains in the moderation audit.'
          : action=='ban' ? 'This bans the account from signing in. Treat this as a serious action.'
          : 'Confirm your moderation decision. Reports alone never trigger a penalty.'),
        const SizedBox(height:12),
        TextField(controller:controller,maxLength:1000,maxLines:3,
          decoration:InputDecoration(labelText:action=='warn'?'Warning message':'Moderator note (optional)',
            border:const OutlineInputBorder())),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirm'))],
    ));
    final note=controller.text.trim();
    // Delay disposal until dialog transitions are complete.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (confirmed != true || !mounted) return;
    setState(() => _busy=true);
    try {
      if (const {'suspend_24h','suspend_7d','ban'}.contains(action)) {
        final result=await _client.functions.invoke('chiplux-moderation-admin',body:{
          'case_id':_s(c['id']),'action':action,'note':note,
        });
        if (result.status < 200 || result.status >= 300) {
          throw StateError('Account action failed (HTTP ${result.status}).');
        }
      } else {
        await _client.rpc('chiplux_moderation_resolve_case',params:{
          'p_case_id':_s(c['id']),'p_action':action,'p_note':note.isEmpty?null:note,
        });
      }
      _message('$label completed.');
      await _reload();
    } catch (e) {
      _message('Moderation action failed: $e');
    } finally {
      if (mounted) setState(() => _busy=false);
    }
  }

  String _formatReasons(Object? raw) {
    if (raw is! Map || raw.isEmpty) return 'Unspecified';
    return raw.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  Widget _caseCard(Map<String,dynamic> c) {
    final kind=_s(c['target_kind']);
    final snap=_snap(c);
    final count=c['report_count'] ?? 0;
    final name=_s(c['target_username']).isNotEmpty ? '@${_s(c['target_username'])}' :
      (_s(c['target_display_name']).isNotEmpty ? _s(c['target_display_name']) : _s(c['target_user_id']));
    final resolved=_s(c['status'])=='resolved';
    final body=_s(snap['body']);
    return GestureDetector(
      onTap: () => _openTarget(c),
      child: Card(color:chipluxSurface,margin:const EdgeInsets.only(bottom:12),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
      child:Padding(padding:const EdgeInsets.all(14),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(kind=='user'?Icons.person_off_outlined:Icons.flag_outlined,color:chipluxGold),
          const SizedBox(width:8),Expanded(child:Text(kind=='user'?'Reported account':
            kind=='music_comment'?'Reported album comment':'Reported comment',
            style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
          Chip(label:Text('$count reports')),
        ]),
        const SizedBox(height:6),
        Text('User: ${name.isEmpty?'Unknown':name}',style:const TextStyle(color:Colors.white70)),
        if(body.isNotEmpty) ...[
          const SizedBox(height:9),Container(width:double.infinity,
          padding:const EdgeInsets.all(12),decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(12),color:chipluxSurfaceLight),
          child:Text(body,maxLines:7,overflow:TextOverflow.ellipsis)),
        ],
        const SizedBox(height:8),
        Text('Reasons: ${_formatReasons(c['reason_counts'])}',
          style:const TextStyle(fontSize:12,color:Colors.white70)),
        Text('Previous confirmed violations: ${c['previous_violations'] ?? 0}',
          style:const TextStyle(fontSize:12,color:Colors.white70)),
        const SizedBox(height:10),
        InkWell(onTap:()=>_openTarget(c),borderRadius:BorderRadius.circular(10),
          child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[
          const Icon(Icons.open_in_new,size:18,color:chipluxGold),const SizedBox(width:8),
          Text(kind=='user'?'Open reported profile':'Open reported comment',
            style:const TextStyle(fontWeight:FontWeight.w700,color:chipluxGold)),
        ]))),
        if(resolved)
          Text('Resolved: ${_s(c['resolution'])}',style:const TextStyle(color:Colors.white54))
        else ...[
          const Divider(height:22),
          Wrap(spacing:8,runSpacing:8,children:[
            OutlinedButton(onPressed:_busy?null:()=>_act(c,'dismiss'),child:const Text('Dismiss')),
            if(kind!='user') OutlinedButton(onPressed:_busy?null:()=>_act(c,'remove_comment'),
              child:const Text('Remove comment')),
            OutlinedButton(onPressed:_busy?null:()=>_act(c,'warn'),child:const Text('Warn')),
            OutlinedButton(onPressed:_busy?null:()=>_act(c,'suspend_24h'),child:const Text('Suspend 24h')),
            OutlinedButton(onPressed:_busy?null:()=>_act(c,'suspend_7d'),child:const Text('Suspend 7d')),
            OutlinedButton(onPressed:_busy?null:()=>_act(c,'ban'),child:const Text('Ban')),
          ]),
        ],
      ]))),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:chipluxBackground,
    appBar:AppBar(title:const Text('Report Moderation'),backgroundColor:chipluxBackground,
      actions:[IconButton(onPressed:_loading?null:_reload,icon:const Icon(Icons.refresh))]),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:Row(children:[
        const Expanded(child:Text('Investigate after 3 unique reports',style:TextStyle(fontSize:12))),
        FilterChip(label:const Text('Resolved'),selected:_showResolved,
          onSelected:(v){setState(()=>_showResolved=v);_reload();}),
      ])),
      if(_busy) const LinearProgressIndicator(),
      Expanded(child:_loading?const Center(child:CircularProgressIndicator()):
        _error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),
          child:SelectableText(_error!,style:const TextStyle(color:Colors.redAccent)))):
        _cases.isEmpty?const Center(child:Text('No moderation cases to review.')):
        RefreshIndicator(onRefresh:_reload,child:ListView.builder(
          padding:const EdgeInsets.fromLTRB(14,4,14,24),itemCount:_cases.length,
          itemBuilder:(_,i)=>_caseCard(_cases[i])))),
    ]),
  );
}

/// Show user-facing warnings inside Settings. Reports are never exposed here.
class ChipluxModerationWarnings extends StatelessWidget {
  const ChipluxModerationWarnings({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('chiplux_moderation_warnings')
          .select('message,created_at')
          .order('created_at', ascending: false)
          .limit(5),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            for (final warning in snapshot.data!)
              Card(
                color: chipluxSurfaceLight,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: chipluxGold),
                  title: const Text('Community warning'),
                  subtitle: Text(warning['message']?.toString() ?? ''),
                ),
              ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}
