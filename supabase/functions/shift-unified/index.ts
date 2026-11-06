import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {createClient} from "npm:@supabase/supabase-js@2.78.0";

const env=(key:string)=>Deno.env.get(key)??"";
const clean=(v:unknown,n=1200)=>typeof v==="string"?v.trim().slice(0,n):"";
const object=(v:unknown):Record<string,unknown>=>v&&typeof v==="object"&&!Array.isArray(v)?v as Record<string,unknown>:{};
const headers={"Content-Type":"application/json","Cache-Control":"no-store","Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info","Access-Control-Allow-Methods":"POST,OPTIONS"};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers});
type Role="text"|"image"|"image_edit"|"voice"|"embedding";
type ModelSlot={id:string;role:Role;model:string;endpoint:string;available:boolean};
const slots:[string,Role][]=[
 ["mistral","text"],["kimi","text"],["nemotron_embed","embedding"],
 ["flux_klein","image"],["qwen_image","image"],["sd35","image"],
 ["flux_kontext","image_edit"],["qwen_edit","image_edit"],
 ["magpie","voice"],["chatterbox","voice"]
];
function configuredModels():ModelSlot[]{
 const shared=env("SHIFT_NVIDIA_API_KEY");
 return slots.map(([id,role])=>{
  const prefix="SHIFT_NVIDIA_"+id.toUpperCase();
  const model=env(prefix+"_MODEL")||(id==="nemotron_embed"?"nvidia/nemotron-3.5-embed-1b":"");
  const endpoint=env(prefix+"_ENDPOINT")||(role==="text"?
   "https://integrate.api.nvidia.com/v1/chat/completions":role==="embedding"?
   "https://integrate.api.nvidia.com/v1/embeddings":"");
  let valid=false;
  try{
   const u=new URL(endpoint);
   valid=u.protocol==="https:"&&!u.username&&!u.password&&!u.hash&&
    (u.hostname==="integrate.api.nvidia.com"||u.hostname==="ai.api.nvidia.com"||
     u.hostname.endsWith(".invocation.api.nvcf.nvidia.com")||
     u.hostname.endsWith(".api.nvidia.com"));
  }catch{/* invalid host */}
  return {id,role,model,endpoint,available:!!(model&&(env(prefix+"_API_KEY")||shared)&&valid)};
 }).filter(x=>x.available);
}
function capabilities(){
 const configured=configuredModels();
 const p=env("SHIFT_AI_PROVIDER").toLowerCase();
 const text=p==="nvidia"?configured.some(x=>x.role==="text"):
  !!(p&&env("SHIFT_AI_API_KEY")&&env("SHIFT_AI_MODEL"));
 const has=(role:Role)=>configured.some(x=>x.role===role);
 const search=!!env("SHIFT_BRAVE_SEARCH_API_KEY")||(p==="openai"&&text);
 return {text,research:search&&text,knowledge:has("embedding"),
  image:has("image"),edit:has("image_edit"),voice:has("voice"),
  creative:text||has("image")||has("voice")||has("image_edit"),
  autoSelection:true,
  note:"Configured describes server-side settings; live inference is not yet verified."};
}
async function userIdentity(req:Request){
 const match=req.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i);
 if(!match)throw Error("unauthorized");
 const caller=createClient(env("SUPABASE_URL"),env("SUPABASE_ANON_KEY"),{
  global:{headers:{Authorization:"Bearer "+match[1]}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await caller.auth.getUser(match[1]);
 if(error||!data.user)throw Error("unauthorized");
 const db=createClient(env("SUPABASE_URL"),env("SUPABASE_SERVICE_ROLE_KEY"),{
  auth:{persistSession:false,autoRefreshToken:false}});
 const {data:work}=await db.from("shift_workspaces").select("id")
  .eq("owner_id",data.user.id).single();
 if(!work)throw Error("workspace_not_found");
 return {token:match[1],workspaceId:work.id as string,db};
}
function intent(prompt:string,hasImage:boolean):{kind:"text"|"research"|"image"|"image_edit"|"voice"|"knowledge";mode:string}{
 const q=prompt.toLowerCase();
 const voice=/\b(voice[\s-]?over|narrat(?:e|ion|or)|speech|spoken audio|text.to.speech|synthesize voice|read aloud|record a voice)\b/.test(q);
 if(voice)return {kind:"voice",mode:"voice"};
 if(hasImage&&/\b(edit|modify|retouch|change|remove|replace|enhance|restyle|background)\b/.test(q))
  return {kind:"image_edit",mode:"edit"};
 const image=/\b(generate|create|draw|design|make|produce)\b.{0,90}\b(image|picture|photo|photograph|poster|visual|illustration|graphic|artwork)\b/.test(q)||
  /\b(image|picture|photo|poster|visual|illustration|graphic|artwork)\b.{0,60}\b(generate|create|draw|design|make)\b/.test(q);
 if(image)return {kind:"image",mode:"image"};
 const knowledge=/\b(search|find|retrieve|look up)\b.{0,55}\b(saved|my research|my sources|bookmarks|knowledge|documents)\b/.test(q)||
  /\b(semantic search|search my research)\b/.test(q);
 if(knowledge)return {kind:"knowledge",mode:"knowledge"};
 const research=/\b(research|latest|current trends|trending now|what.s happening|competitors|market research|look online|search the web)\b/.test(q);
 if(research)return {kind:"research",mode:/competitor/.test(q)?"competitors":"research"};
 const calendar=/\b(calendar|posting schedule|schedule ideas|content plan for \d+ days|plan posts for)\b/.test(q);
 if(calendar)return {kind:"text",mode:"calendar"};
 if(/\b(strategy|campaign plan|content pillars|marketing plan|positioning)\b/.test(q))
  return {kind:"text",mode:"strategy"};
 if(/\b(improve|rewrite|shorten|polish|rephrase|edit caption)\b/.test(q))
  return {kind:"text",mode:"improve"};
 return {kind:"text",mode:"ideas"};
}
async function delegate(path:string,token:string,payload:Record<string,unknown>){
 // Calls to trusted SHIFT Edge Functions only. The user's JWT is preserved
 // so downstream handlers enforce the same workspace ownership and rate limits.
 const url=env("SUPABASE_URL")+"/functions/v1/"+path;
 const res=await fetch(url,{method:"POST",signal:AbortSignal.timeout(36000),headers:{
  "Content-Type":"application/json","Authorization":"Bearer "+token,
  "apikey":env("SUPABASE_ANON_KEY")},body:JSON.stringify(payload)});
 let result:Record<string,unknown>;
 try{result=object(await res.json())}catch{throw Error("downstream_invalid_response")}
 return {status:res.status,data:result};
}
async function handle(req:Request){
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
 if(req.method!=="POST")return reply({error:"method_not_allowed"},405);
 const user=await userIdentity(req);
 let body:Record<string,unknown>;
 try{body=object(await req.json())}catch{return reply({error:"invalid_json"},400)}
 const action=clean(body.action,40);
 const caps=capabilities();
 if(action==="status"){
  return reply({capabilities:caps,models:configuredModels().map(x=>({
   role:x.role,id:x.id,configured:true,verified:false
  })),autoSelection:true});
 }
 if(["job_status","history","plan_items","accept_plan"].includes(action)){
  const fields:Record<string,unknown>={action};
  if(action==="job_status")fields.jobId=clean(body.jobId,60);
  if(action==="accept_plan")fields.itemId=clean(body.itemId,60);
  const out=await delegate("shift-ai",user.token,fields);
  return reply(out.data,out.status);
 }
 if(action==="media_history"){
  const out=await delegate("shift-nvidia",user.token,{action:"history"});
  return reply(out.data,out.status);
 }
 if(action==="index_knowledge"){
  if(!caps.knowledge)return reply({error:"knowledge_not_configured"},503);
  const out=await delegate("shift-nemotron",user.token,{action:"index"});
  return reply(out.data,out.status);
 }
 if(action!=="run")return reply({error:"unknown_action"},400);
 const prompt=clean(body.prompt,1500);
 const requestKey=clean(body.requestKey,150);
 if(prompt.length<5||!/^shift-workspace-[\w-]{8,120}$/.test(requestKey))
  return reply({error:"invalid_request"},400);
 const imagePath=clean(body.sourcePath,500);
 if(imagePath&&!imagePath.startsWith("http")&&imagePath.includes(".."))
  return reply({error:"invalid_source"},400);
 const target=intent(prompt,!!imagePath);
 if(target.kind==="knowledge"){
  if(!caps.knowledge)return reply({error:"knowledge_not_configured"},503);
  const out=await delegate("shift-nemotron",user.token,{action:"search",query:prompt});
  return reply(out.data,out.status);
 }
 if(target.kind==="image"||target.kind==="image_edit"||target.kind==="voice"){
  const role=target.kind;
  const candidates=configuredModels().filter(x=>x.role===role);
  if(!candidates.length)return reply({error:"capability_not_configured",capability:role},503);
  // Explicit priority is stable; no client-controlled model IDs.
  const chosen=candidates[0];
  const operation=role==="voice"?"synthesize_voice":role==="image_edit"?"edit_image":"generate_image";
  const out=await delegate("shift-nvidia",user.token,{
   action:operation,modelId:chosen.id,prompt,
   ...(role==="image_edit"?{sourcePath:imagePath}:{}),
   ...(role==="voice"?{language:"en-US"}:{})
  });
  return reply(out.data,out.status);
 }
 if(!caps.text)return reply({error:"text_not_configured"},503);
 if(target.kind==="research"&&!caps.research)
  return reply({error:"research_provider_not_configured"},503);
 const out=await delegate("shift-ai",user.token,{
  action:"run",mode:target.mode,prompt,requestKey,async:true
 });
 return reply({...out.data,route:target.kind,mode:target.mode},out.status);
}
Deno.serve(async req=>{
 try{return await handle(req)}
 catch(error){
  const safe=error instanceof Error&&error.message==="unauthorized"?"unauthorized":
   error instanceof Error&&error.message==="downstream_invalid_response"?
   "downstream_invalid_response":"unified_ai_unavailable";
  console.error("SHIFT unified AI",{error:safe});
  return reply({error:safe},safe==="unauthorized"?401:502);
 }
});
