import 'dart:ui';
import 'package:flutter/material.dart';
import 'feature_hub.dart';

void main() => runApp(const ShiftApp());

class ShiftApp extends StatefulWidget {
  const ShiftApp({super.key});
  @override
  State<ShiftApp> createState() => _ShiftAppState();
}
class _ShiftAppState extends State<ShiftApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: dark ? const Color(0xFF090A0C) : const Color(0xFFF5F5F7),
      colorScheme: ColorScheme.fromSeed(
        seedColor: dark ? Colors.white : Colors.black,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHIFT',
      theme: theme,
      home: ShiftHome(dark: dark, onTheme: () => setState(() => dark = !dark)),
    );
  }
}
class ShiftHome extends StatefulWidget {
  const ShiftHome({super.key, required this.dark, required this.onTheme});
  final bool dark;
  final VoidCallback onTheme;
  @override
  State<ShiftHome> createState() => _ShiftHomeState();
}
class _ShiftHomeState extends State<ShiftHome> {
  int selected = 0;
  final pages = const ['Overview','Discover','Create','Calendar','Analytics','Settings'];
  final icons = const [Icons.space_dashboard_outlined,Icons.explore_outlined,Icons.auto_awesome_outlined,Icons.calendar_month_outlined,Icons.insights_outlined,Icons.settings_outlined];
  final List<Map<String,String>> drafts = [
    {'title':'The future of creativity','platform':'Instagram','status':'Scheduled'},
    {'title':'Small steps, big ideas','platform':'Facebook','status':'Needs approval'},
    {'title':'Behind every great brand','platform':'Instagram','status':'Draft'},
  ];
  final idea = TextEditingController();
  final caption = TextEditingController();
  String platform = 'Instagram';
  @override
  void dispose() { idea.dispose(); caption.dispose(); super.dispose(); }
  void message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Widget glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: widget.dark ? Colors.white.withValues(alpha: .065) : Colors.white.withValues(alpha: .77),
            border: Border.all(color: widget.dark ? Colors.white12 : Colors.black12),
            borderRadius: BorderRadius.circular(23),
          ),
          child: child,
        ),
      ),
    );
  }
  Widget header(String eyebrow,String title,String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
    Text(eyebrow,style:TextStyle(fontSize:10,letterSpacing:2,fontWeight:FontWeight.w800,color:Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height:10),
    Text(title,style:const TextStyle(fontSize:31,fontWeight:FontWeight.w800,letterSpacing:-1.3)),
    const SizedBox(height:6),
    Text(subtitle,style:TextStyle(fontSize:13,color:Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height:24),
  ]);
  Widget action(String label, VoidCallback tap, {IconData icon = Icons.arrow_forward}) => FilledButton.icon(onPressed:tap,icon:Icon(icon,size:17),label:Text(label));
  Widget stat(String label,String value,IconData icon) => glass(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Expanded(child:Text(label,style:const TextStyle(fontSize:12))),Icon(icon,size:17)]),
    const SizedBox(height:22),
    Text(value,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w800)),
  ]));
  Widget postTile(Map<String,String> post) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(width:47,height:47,alignment:Alignment.center,decoration:BoxDecoration(color:widget.dark?Colors.white12:Colors.black12,borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.image_outlined)),
    title: Text(post['title']!,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
    subtitle: Text("${post['platform']} · ${post['status']}",style:const TextStyle(fontSize:11)),
  );
  Widget overview() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    header('YOUR SOCIAL COMMAND CENTER','Good to see you again.','Your content, ideas and workflow in one place.'),
    Row(children:[Expanded(child:stat('Scheduled',drafts.where((x)=>x['status']=='Scheduled').length.toString(),Icons.calendar_today_outlined)),const SizedBox(width:12),Expanded(child:stat('Drafts',drafts.where((x)=>x['status']=='Draft').length.toString(),Icons.edit_note))]),
    const SizedBox(height:12),
    Row(children:[Expanded(child:stat('Approvals',drafts.where((x)=>x['status']=='Needs approval').length.toString(),Icons.verified_outlined)),const SizedBox(width:12),Expanded(child:stat('Accounts','0',Icons.link_off_outlined))]),
    const SizedBox(height:20),
    glass(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Upcoming content',style:TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
      const SizedBox(height:12),
      ...drafts.take(3).map(postTile),
      const SizedBox(height:10),
      action('Create a post',()=>setState(()=>selected=2),icon:Icons.add),
    ])),
    const SizedBox(height:14),
    glass(child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('SHIFT intelligence',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
      SizedBox(height:10),
      Text('AI research is not connected yet. Live trends and recommendations will appear here.',style:TextStyle(fontSize:13)),
    ])),
  ]);
  Widget discover() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    header('CONTENT INTELLIGENCE','Find your next idea.','Sample editorial suggestions — not live research.'),
    ...['Behind-the-scenes storytelling','Educational carousel posts','Community questions'].map((topic)=>Padding(
      padding:const EdgeInsets.only(bottom:12),
      child:glass(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Icon(Icons.auto_awesome_outlined,size:22),const SizedBox(height:12),
        Text(topic,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700)),
        const SizedBox(height:9),
        const Text('An example content angle to explore with your audience.',style:TextStyle(fontSize:12)),
        const SizedBox(height:12),
        TextButton(onPressed:(){idea.text=topic;setState(()=>selected=2);},child:const Text('Use this idea →')),
      ])),
    )),
    action('Research live topics',()=>message('Research API not connected yet.'),icon:Icons.search),
  ]);
  Widget create() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    header('CONTENT STUDIO','Create something great.','Write, refine and prepare your next post.'),
    glass(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      TextField(controller:idea,decoration:const InputDecoration(labelText:'Content idea',hintText:'What should this post be about?',border:OutlineInputBorder())),
      const SizedBox(height:14),
      TextField(controller:caption,maxLines:5,decoration:const InputDecoration(labelText:'Caption',hintText:'Write your caption...',border:OutlineInputBorder())),
      const SizedBox(height:14),
      DropdownButtonFormField<String>(initialValue:platform,decoration:const InputDecoration(labelText:'Platform',border:OutlineInputBorder()),items:['Instagram','Facebook','X'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>setState(()=>platform=v??platform)),
      const SizedBox(height:16),
      Wrap(spacing:9,runSpacing:9,children:[
        action('Save draft',(){
          if(caption.text.trim().isEmpty){message('Write a caption first.');return;}
          setState(()=>drafts.insert(0,{'title':idea.text.trim().isEmpty?'Untitled content':idea.text.trim(),'platform':platform,'status':'Draft'}));
          caption.clear();idea.clear();message('Draft saved for this session only.');
        },icon:Icons.save_outlined),
        OutlinedButton.icon(onPressed:()=>message('AI generation requires the cloud backend.'),icon:const Icon(Icons.auto_awesome,size:17),label:const Text('Generate with AI')),
      ]),
    ])),
    const SizedBox(height:15),
    glass(child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Image preview',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
      SizedBox(height:15),
      SizedBox(height:140,child:Center(child:Icon(Icons.image_outlined,size:54))),
      Text('Image generation will be available when AI services are connected.',style:TextStyle(fontSize:12)),
    ])),
  ]);
  Widget calendar() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    header('CONTENT PLANNING','Your content queue.','Manage your drafts and upcoming posts.'),
    glass(child:Column(children:[
      ...drafts.map(postTile),
      const SizedBox(height:12),
      const Text('Demo only: nothing is scheduled or published. Drafts reset when the app restarts.',style:TextStyle(fontSize:12)),
    ])),
  ]);
  Widget analytics() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    header('PERFORMANCE','Know your impact.','Understand what works for your audience.'),
    Row(children:[Expanded(child:stat('Reach','—',Icons.visibility_outlined)),const SizedBox(width:12),Expanded(child:stat('Engagement','—',Icons.favorite_outline))]),
    const SizedBox(height:15),
    glass(child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('No analytics yet',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
      SizedBox(height:12),
      Text('Connect an authorized social account to access real metrics. No numbers are fabricated in this preview.'),
    ])),
  ]);
  Widget settings() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    header('YOUR WORKSPACE','Make SHIFT yours.','Account connections and preferences.'),
    glass(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Appearance',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Dark glass theme'),value:widget.dark,onChanged:(_)=>widget.onTheme()),
      const Divider(),
      const Text('Social accounts',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
      OutlinedButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const ShiftFeatureHub())),icon:const Icon(Icons.tune),label:const Text('Open workspace tools')),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.camera_alt_outlined),title:const Text('Instagram'),subtitle:const Text('Not connected'),trailing:const Icon(Icons.add),onTap:()=>message('Instagram OAuth is not configured.')),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.people_outline),title:const Text('Facebook'),subtitle:const Text('Not connected'),trailing:const Icon(Icons.add),onTap:()=>message('Facebook OAuth is not configured.')),
      const Divider(),
      const Text('Publishing mode: Hybrid',style:TextStyle(fontWeight:FontWeight.w700)),
      const SizedBox(height:8),
      const Text('Routine posts can be preauthorized when cloud publishing is connected. Sensitive posts require approval.',style:TextStyle(fontSize:12)),
    ])),
  ]);
  @override
  Widget build(BuildContext context) {
    final views=[overview,discover,create,calendar,analytics,settings];
    return Scaffold(
      appBar:AppBar(toolbarHeight:68,title:Row(children:[
        Container(width:36,height:36,alignment:Alignment.center,decoration:BoxDecoration(color:widget.dark?Colors.white:Colors.black,borderRadius:BorderRadius.circular(12)),child:Text('S',style:TextStyle(color:widget.dark?Colors.black:Colors.white,fontWeight:FontWeight.w900,fontSize:24))),
        const SizedBox(width:10),const Text('SHIFT',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:-1.5)),
      ]),actions:[IconButton(tooltip:'Workspace tools',onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const ShiftFeatureHub())),icon:const Icon(Icons.tune)),IconButton(onPressed:widget.onTheme,icon:Icon(widget.dark?Icons.light_mode_outlined:Icons.dark_mode_outlined)),IconButton(onPressed:()=>message('Notifications are not connected.'),icon:const Icon(Icons.notifications_none)),const SizedBox(width:10)]),
      body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(18,20,18,110),children:[views[selected]()])),
      bottomNavigationBar:NavigationBar(
        selectedIndex:selected,
        onDestinationSelected:(i)=>setState(()=>selected=i),
        labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
        destinations:List.generate(pages.length,(i)=>NavigationDestination(icon:Icon(icons[i],size:21),label:pages[i])),
      ),
    );
  }
}
