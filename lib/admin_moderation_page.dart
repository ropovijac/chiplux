import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/profile_service.dart';

const Color _adminBackground = Color(0xFF07111C);
const Color _adminSurface = Color(0xFF111D2A);
const Color _adminSurfaceLight = Color(0xFF162536);
const Color _adminCyan = Color(0xFF43E8FF);

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});
  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage>
    with SingleTickerProviderStateMixin {
  final client = Supabase.instance.client;
  late final TabController _tabs;
  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> userReports = [];
  List<Map<String, dynamic>> commentReports = [];
  List<Map<String, dynamic>> bugReports = [];
  final Map<String, Map<String, dynamic>> profiles = {};
  final Map<String, Map<String, dynamic>> comments = {};

  bool get _allowed => ProfileService.instance.isDeveloper;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    if (!_allowed) {
      if (mounted) setState(() { loading = false; errorMessage = 'Developer access required.'; });
      return;
    }
    try {
      final raw = await Future.wait([
        client.from('user_reports').select().order('created_at', ascending: false),
        client.from('comment_reports').select().order('created_at', ascending: false),
        client.from('bug_reports').select().order('created_at', ascending: false),
      ]);
      final users = List<Map<String,dynamic>>.from(raw[0] as List);
      final commentRows = List<Map<String,dynamic>>.from(raw[1] as List);
      final bugs = List<Map<String,dynamic>>.from(raw[2] as List);

      final profileIds = <String>{};
      for (final r in users) {
        final a=r['reporter_id']?.toString(); final b=r['reported_user_id']?.toString();
        if(a!=null) profileIds.add(a); if(b!=null) profileIds.add(b);
      }
      for (final r in bugs) { final id=r['user_id']?.toString(); if(id!=null) profileIds.add(id); }

      final commentIds = commentRows.map((r)=>r['comment_id']?.toString()).whereType<String>().toSet().toList();
      final loadedComments=<Map<String,dynamic>>[];
      if(commentIds.isNotEmpty){
        final rows=await client.from('media_comments').select('id, user_id, body, media_type, tmdb_id, season_number, episode_number').inFilter('id',commentIds);
        loadedComments.addAll(List<Map<String,dynamic>>.from(rows));
        for(final c in loadedComments){final id=c['user_id']?.toString(); if(id!=null) profileIds.add(id);}
      }
      final loadedProfiles=<Map<String,dynamic>>[];
      if(profileIds.isNotEmpty){
        final rows=await client.from('profiles').select('id, display_name, username, avatar_url').inFilter('id',profileIds.toList());
        loadedProfiles.addAll(List<Map<String,dynamic>>.from(rows));
      }
      if(!mounted)return;
      setState((){
        userReports=users; commentReports=commentRows; bugReports=bugs;
        profiles..clear()..addEntries(loadedProfiles.where((p)=>p['id']!=null).map((p)=>MapEntry(p['id'].toString(),p)));
        comments..clear()..addEntries(loadedComments.where((c)=>c['id']!=null).map((c)=>MapEntry(c['id'].toString(),c)));
        loading=false; errorMessage=null;
      });
    }catch(e){if(mounted)setState((){loading=false;errorMessage='Could not load moderation reports: $e';});}
  }

  String _who(String? id){
    if(id==null)return 'Unknown user'; final p=profiles[id]; if(p==null)return id;
    final n=p['display_name']?.toString().trim()??''; final u=p['username']?.toString().trim()??'';
    if(n.isNotEmpty&&u.isNotEmpty)return '$n (@$u)'; if(u.isNotEmpty)return '@$u'; return n.isNotEmpty?n:id;
  }

  Future<void> _status(String table,Object id,String value) async {
    try{await client.from(table).update({'status':value}).eq('id',id);await _load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not update report: $e')));}
  }

  Future<void> _deleteComment(Map<String,dynamic> r) async {
    final id=r['comment_id']?.toString(); if(id==null)return;
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      backgroundColor:_adminSurface,title:const Text('Delete reported comment?'),
      content:const Text('This permanently removes the comment.',style:TextStyle(color:Colors.white70)),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete',style:TextStyle(color:Colors.redAccent)))],));
    if(ok!=true)return; await client.from('media_comments').delete().eq('id',id); await _load();
  }

  Widget _actions(String table,Object id,{VoidCallback? deleteComment})=>Wrap(spacing:8,runSpacing:8,children:[
    OutlinedButton(onPressed:()=>_status(table,id,'reviewing'),child:const Text('Reviewing')),
    OutlinedButton(onPressed:()=>_status(table,id,'dismissed'),child:const Text('Dismiss')),
    FilledButton(onPressed:()=>_status(table,id,'resolved'),child:const Text('Resolve')),
    if(deleteComment!=null)TextButton.icon(onPressed:deleteComment,icon:const Icon(Icons.delete_outline_rounded,color:Colors.redAccent),label:const Text('Delete comment',style:TextStyle(color:Colors.redAccent))),
  ]);

  Widget _card(String header,String status,String title,String subtitle,String body,Widget actions)=>Container(
    margin:const EdgeInsets.fromLTRB(14,8,14,8),padding:const EdgeInsets.all(15),
    decoration:BoxDecoration(color:_adminSurface,borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white.withValues(alpha:.06))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Text(header,style:const TextStyle(color:_adminCyan,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1)),const Spacer(),
        Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:_adminCyan.withValues(alpha:.09),borderRadius:BorderRadius.circular(99)),child:Text(status.toUpperCase(),style:const TextStyle(color:_adminCyan,fontSize:9,fontWeight:FontWeight.w800)))]),
      const SizedBox(height:12),Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),const SizedBox(height:3),
      Text(subtitle,style:const TextStyle(color:Colors.white38,fontSize:11)),const SizedBox(height:12),
      Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_adminSurfaceLight,borderRadius:BorderRadius.circular(12)),child:Text(body,style:const TextStyle(color:Colors.white70,height:1.4))),
      const SizedBox(height:12),actions]));

  Widget _user(Map<String,dynamic> r){final id=r['id'];final s=r['status']?.toString()??'open';final reason=r['reason']?.toString()??'No reason';final d=r['details']?.toString().trim()??'';
    return _card('USER REPORT',s,_who(r['reported_user_id']?.toString()),'Reported by ${_who(r['reporter_id']?.toString())}',d.isEmpty?reason:'$reason\n\n$d',_actions('user_reports',id));}
  Widget _comment(Map<String,dynamic> r){final id=r['id'];final s=r['status']?.toString()??'open';final cid=r['comment_id']?.toString();final c=cid==null?null:comments[cid];final type=r['report_type']?.toString()??'comment';
    return _card(type=='spoiler'?'SPOILER REPORT':'COMMENT REPORT',s,_who(c?['user_id']?.toString()),'Reported by ${_who(r['reporter_id']?.toString())}',c?['body']?.toString()??'Comment no longer exists.',_actions('comment_reports',id,deleteComment:cid==null?null:()=>_deleteComment(r)));}
  Widget _bug(Map<String,dynamic> r){final id=r['id'];return _card('BUG REPORT',r['status']?.toString()??'open',_who(r['user_id']?.toString()),r['created_at']?.toString()??'',r['description']?.toString()??'',_actions('bug_reports',id));}

  Widget _list(List<Map<String,dynamic>> rows,Widget Function(Map<String,dynamic>) builder){
    if(loading)return const Center(child:CircularProgressIndicator()); if(errorMessage!=null)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(errorMessage!,textAlign:TextAlign.center)));
    if(rows.isEmpty)return const Center(child:Text('No reports.',style:TextStyle(color:Colors.white54)));
    return RefreshIndicator(onRefresh:_load,child:ListView.builder(physics:const AlwaysScrollableScrollPhysics(),itemCount:rows.length,itemBuilder:(c,i)=>builder(rows[i])));
  }

  @override Widget build(BuildContext context){
    if(!_allowed)return const Scaffold(backgroundColor:_adminBackground,body:Center(child:Text('Developer access required.')));
    return Scaffold(backgroundColor:_adminBackground,appBar:AppBar(backgroundColor:_adminBackground,title:const Text('Admin Moderation'),bottom:TabBar(controller:_tabs,tabs:const[Tab(text:'Users'),Tab(text:'Comments'),Tab(text:'Bugs')])),
      body:TabBarView(controller:_tabs,children:[_list(userReports,_user),_list(commentReports,_comment),_list(bugReports,_bug)]));
  }
  @override void dispose(){_tabs.dispose();super.dispose();}
}
