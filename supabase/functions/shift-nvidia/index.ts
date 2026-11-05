import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {createClient} from "npm:@supabase/supabase-js@2.78.0";

const env=(key:string)=>Deno.env.get(key)??"";
const clean=(v:unknown,n=2000)=>typeof v==="string"?v.trim().slice(0,n):"";
const obj=(v:unknown):Record<string,unknown>=>v&&typeof v==="object"&&!Array.isArray(v)?v as Record<string,unknown>:{};
const cors={"Content-Type":"application/json","Cache-Control":"no-store","Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info","Access-Control-Allow-Methods":"POST,OPTIONS"};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:cors});
type Category="text"|"image"|"image_edit"|"voice";
type Slot={id:string;label:string;type:Category;hint:string;defaultModel:string;protocol:string};
const slots:Slot[]=[
 {id:"mistral",label:"Mistral Large 4",type:"text",hint:"Primary writing and research analysis",defaultModel:"",protocol:"chat"},
 {id:"kimi",label:"Kimi K3.1 Pro",type:"text",hint:"Complex analysis",defaultModel:"",protocol:"chat"},
 {id:"flux_klein",label:"FLUX 3 Klein",type:"image",hint:"General image generation",defaultModel:"",protocol:"images"},
 {id:"qwen_image",label:"Qwen Image",type:"image",hint:"Text-rich graphics",defaultModel:"",protocol:"images"},
 {id:"sd35",label:"Stable Diffusion 3.5 Large",type:"image",hint:"Fallback image generator; check license",defaultModel:"",protocol:"images"},
 {id:"qwen_edit",label:"Qwen Image Edit NVPCB",type:"image_edit",hint:"PCB-specific; verify this model suits the input",defaultModel:"",protocol:"image_json"},
 {id:"flux_kontext",label:"FLUX.1 Kontext Dev",type:"image_edit",hint:"Editing; verify commercial license",defaultModel:"",protocol:"image_json"},
 {id:"magpie",label:"Magpie Multilingual TTS",type:"voice",hint:"NVIDIA Speech NIM",defaultModel:"magpie-tts-multilingual",protocol:"nvidia_tts"},
 {id:"chatterbox",label:"Chatterbox Multilingual TTS",type:"voice",hint:"NVIDIA Speech NIM / self-hosted",defaultModel:"chatterbox-multilingual-tts",protocol:"nvidia_tts"},
];
function config(slot:Slot){
 const key=env("SHIFT_NVIDIA_"+slot.id.toUpperCase()+"_API_KEY")||env("SHIFT_NVIDIA_API_KEY");
 const model=env("SHIFT_NVIDIA_"+slot.id.toUpperCase()+"_MODEL")||slot.defaultModel;
 const defaultChat="https://integrate.api.nvidia.com/v1/chat/completions";
 const endpoint=env("SHIFT_NVIDIA_"+slot.id.toUpperCase()+"_ENDPOINT")||(slot.type==="text"?defaultChat:"");
 // Endpoints are administrator-supplied secrets, never accepted in user requests.
 let valid=false;
 try{
  const u=new URL(endpoint);
  valid=u.protocol==="https:"&&!u.username&&!u.password&&!u.hash
   &&(u.hostname==="integrate.api.nvidia.com"||u.hostname==="ai.api.nvidia.com"
     ||u.hostname.endsWith(".invocation.api.nvcf.nvidia.com")
     ||u.hostname.endsWith(".api.nvidia.com"));
 }catch{/* not configured */}
 const protocol=env("SHIFT_NVIDIA_"+slot.id.toUpperCase()+"_PROTOCOL")||slot.protocol;
 const supported=(slot.type==="text"&&protocol==="chat")
   ||(slot.type==="image"&&protocol==="images")
   ||(slot.type==="image_edit"&&protocol==="image_json")
   ||(slot.type==="voice"&&protocol==="nvidia_tts");
 return {key,model,endpoint,protocol,configured:!!key&&!!model&&valid&&supported};
}
const admin=()=>createClient(env("SUPABASE_URL"),env("SUPABASE_SERVICE_ROLE_KEY"),
 {auth:{persistSession:false,autoRefreshToken:false}});
async function auth(req:Request){
 const match=req.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i);
 if(!match)throw Error("unauthorized");
 const userClient=createClient(env("SUPABASE_URL"),env("SUPABASE_ANON_KEY"),
  {global:{headers:{Authorization:"Bearer "+match[1]}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await userClient.auth.getUser(match[1]);
 if(error||!data.user)throw Error("unauthorized");
 const db=admin();
 const {data:workspace}=await db.from("shift_workspaces").select("id").eq("owner_id",data.user.id).single();
 if(!workspace)throw Error("workspace_not_found");
 return {db,wid:String(workspace.id),uid:data.user.id};
}
function decodeBase64(raw:string,max:number){
 const str=raw.replace(/^data:[^,]+,/, "");
 if(str.length>max*1.38||str.length===0||!/^[A-Za-z0-9+/_=-]+$/.test(str))throw Error("invalid_media_output");
 const encoded=str.replace(/-/g,"+").replace(/_/g,"/");
 const binary=atob(encoded);
 if(binary.length===0||binary.length>max)throw Error("media_too_large");
 const out=new Uint8Array(binary.length);
 for(let i=0;i<binary.length;i++)out[i]=binary.charCodeAt(i);
 return out;
}
function sniff(bytes:Uint8Array):{ext:string;mime:string}|null{
 if(bytes.length>8&&bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71)
  return {ext:"png",mime:"image/png"};
 if(bytes.length>3&&bytes[0]===255&&bytes[1]===216&&bytes[2]===255)
  return {ext:"jpg",mime:"image/jpeg"};
 if(bytes.length>12&&new TextDecoder().decode(bytes.slice(0,4))==="RIFF"
   &&new TextDecoder().decode(bytes.slice(8,12))==="WEBP")
  return {ext:"webp",mime:"image/webp"};
 return null;
}
async function save(db:ReturnType<typeof admin>,uid:string,wid:string,bytes:Uint8Array,mime:string,ext:string){
 const path=uid+"/"+wid+"/ai/"+crypto.randomUUID()+"."+ext;
 const {error}=await db.storage.from("shift-media").upload(path,bytes,{
   contentType:mime,upsert:false,cacheControl:"3600"});
 if(error)throw Error("media_storage_failed");
 const {data:link,error:linkError}=await db.storage.from("shift-media").createSignedUrl(path,600);
 if(linkError||!link?.signedUrl)throw Error("media_link_failed");
 return {path,url:link.signedUrl,expiresIn:600};
}
async function withDeadline(url:string,init:RequestInit){
 const res=await fetch(url,{...init,signal:AbortSignal.timeout(28000)});
 if(res.status===429)throw Error("nvidia_rate_limited");
 if(res.status===401||res.status===403)throw Error("nvidia_credentials_rejected");
 if(!res.ok)throw Error("nvidia_request_failed");
 return res;
}
async function handler(req:Request){
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
 if(req.method!=="POST")return reply({error:"method_not_allowed"},405);
 const actor=await auth(req);
 let body:Record<string,unknown>;
 try{body=obj(await req.json());}catch{return reply({error:"invalid_json"},400)}
 const action=clean(body.action,30);
 if(action==="history"){
  const {data,error}=await actor.db.from("shift_nvidia_media")
    .select("id,model_slot,model_id,media_type,prompt,storage_path,created_at")
    .eq("workspace_id",actor.wid).order("created_at",{ascending:false}).limit(40);
  if(error)throw Error("history_unavailable");
  const items=[];
  for(const item of data??[]){
    const {data:signed}=await actor.db.storage.from("shift-media")
      .createSignedUrl(item.storage_path,600);
    items.push({id:item.id,modelId:item.model_slot,model:item.model_id,
      type:item.media_type,prompt:item.prompt,createdAt:item.created_at,
      path:item.storage_path,url:signed?.signedUrl??null});
  }
  return reply({items});
 }
 if(action==="status")return reply({models:slots.map(s=>{
  const c=config(s);return {id:s.id,label:s.label,type:s.type,hint:s.hint,model:c.model||null,
   configured:c.configured,endpointConfigured:!!c.endpoint,protocol:c.protocol,
   state:c.configured?"configured_not_tested":"needs_configuration"};
 }),keyLocation:"Supabase Edge Function secrets",tested:false});
 const slot=slots.find(x=>x.id===clean(body.modelId,35));
 if(!slot)return reply({error:"unknown_model"},400);
 const c=config(slot);
 if(!c.configured)return reply({error:"model_not_configured"},503);
 if(action==="test"){
  // Readiness check validates trusted backend configuration only;
  // no provider quota is consumed or real inference claimed.
  return reply({configured:true,model:c.model,endpointConfigured:true,verified:false});
 }
 if(!((action==="generate_image"&&slot.type==="image")||
   (action==="edit_image"&&slot.type==="image_edit")||
   (action==="synthesize_voice"&&slot.type==="voice")))
  return reply({error:"unsupported_action_for_model"},400);
 const prompt=clean(body.prompt,1300);
 if(prompt.length<5)return reply({error:"invalid_prompt"},400);
 const {data:brand}=await actor.db.from("shift_brands")
  .select("name,description,audience,brand_voice,guidelines,settings")
  .eq("workspace_id",actor.wid).maybeSingle();
 const brandContext=brand?[
   clean(brand.name,120),clean(brand.description,300),
   "Audience: "+clean(brand.audience,150),
   "Style: "+clean(brand.brand_voice,150),
   "Brand rules: "+clean(brand.guidelines,350)
 ].filter(Boolean).join("; "):"";
 // Voice is spoken verbatim: do not synthesize private brand instructions.
 const mediaPrompt=slot.type==="voice"?prompt:
   (brandContext?prompt+"\nBrand context: "+brandContext:prompt).slice(0,2200);
 const {data:allowed,error:rateError}=await actor.db.rpc("shift_ai_allow_request",{
  p_user:actor.uid,p_workspace:actor.wid,p_category:"image"});
 if(rateError||allowed!==true)return reply({error:"media_generation_limit_reached"},429);
 try{
  let response:Response;
  if(slot.type==="voice"){
   const locale=clean(body.language,20)||"en-US",voice=clean(body.voice,100)||"Magpie-Multilingual.EN-US.Aria";
   if(!/^[a-z]{2,3}-[A-Z]{2}$/.test(locale)||!/^[\w.-]{3,100}$/.test(voice))return reply({error:"invalid_voice"},400);
   const form=new FormData();
   form.set("text",prompt.slice(0,350));form.set("language",locale);form.set("voice",voice);
   form.set("encoding","LINEAR_PCM");form.set("sample_rate_hz","44100");
   response=await withDeadline(c.endpoint,{method:"POST",headers:{Authorization:"Bearer "+c.key},body:form});
   const type=response.headers.get("content-type")??"";
   if(!type.includes("audio/")&&!type.includes("octet-stream"))throw Error("unexpected_audio_response");
   const size=Number(response.headers.get("content-length")||"0");
   if(size>8*1024*1024)throw Error("media_too_large");
   const bytes=new Uint8Array(await response.arrayBuffer());
   if(bytes.length>8*1024*1024)throw Error("media_too_large");
   const saved=await save(actor.db,actor.uid,actor.wid,bytes,"audio/wav","wav");
   const {error:historyError}=await actor.db.from("shift_nvidia_media").insert({
    workspace_id:actor.wid,user_id:actor.uid,model_slot:slot.id,
    model_id:c.model,media_type:"voice",prompt,storage_path:saved.path,mime_type:"audio/wav"});
   if(historyError)throw Error("media_history_failed");
   return reply({type:"voice",modelId:slot.id,model:c.model,...saved});
  }
  let source:string|undefined;
  if(action==="edit_image"){
   const path=clean(body.sourcePath,500);
   if(!path.startsWith(actor.uid+"/"+actor.wid+"/")||path.includes(".."))return reply({error:"invalid_source_image"},403);
   const {data,error}=await actor.db.storage.from("shift-media").download(path);
   if(error||!data)return reply({error:"source_not_found"},404);
   const raw=new Uint8Array(await data.arrayBuffer());
   if(raw.length>4*1024*1024)throw Error("source_too_large");
   const format=sniff(raw);
   if(!format)throw Error("invalid_source_image");
   let bits="";for(let i=0;i<raw.length;i+=8192)
     bits+=String.fromCharCode(...raw.slice(i,i+8192));
   source="data:"+format.mime+";base64,"+btoa(bits);
  }
  // Only explicit model-specific NVIDIA HTTPS endpoints may be used for image requests.
  // JSON image protocols require base64 output. URL-only APIs are not implicitly fetched.
  const payload:Record<string,unknown>={model:c.model,prompt:mediaPrompt,response_format:"b64_json",n:1};
  if(source)payload.image=source;
  response=await withDeadline(c.endpoint,{method:"POST",
   headers:{"Authorization":"Bearer "+c.key,"Content-Type":"application/json"},
   body:JSON.stringify(payload)});
  const returned=await response.json();
  const encoded=clean(returned?.data?.[0]?.b64_json||returned?.artifacts?.[0]?.base64||returned?.image,12500000);
  if(!encoded)throw Error("image_protocol_unavailable");
  const bytes=decodeBase64(encoded,8*1024*1024);
  const format=sniff(bytes);
  if(!format)throw Error("unsupported_image_format");
  const saved=await save(actor.db,actor.uid,actor.wid,bytes,format.mime,format.ext);
  const {error:historyError}=await actor.db.from("shift_nvidia_media").insert({
   workspace_id:actor.wid,user_id:actor.uid,model_slot:slot.id,
   model_id:c.model,media_type:slot.type,prompt,storage_path:saved.path,
   mime_type:format.mime});
  if(historyError)throw Error("media_history_failed");
  return reply({type:slot.type,modelId:slot.id,model:c.model,...saved});
 }catch(e){
  const code=e instanceof Error?e.message:"model_error";
  const safe=["nvidia_rate_limited","nvidia_credentials_rejected","nvidia_request_failed",
   "media_too_large","invalid_media_output","image_protocol_unavailable",
   "unsupported_image_format","unexpected_audio_response","source_not_found","source_too_large",
   "media_storage_failed","media_link_failed","invalid_source_image","media_history_failed"].includes(code)?code:"model_error";
  return reply({error:safe},safe==="nvidia_rate_limited"?429:502);
 }
}
Deno.serve(async req=>{try{return await handler(req)}catch(e){
 const code=e instanceof Error&&e.message==="unauthorized"?"unauthorized":"request_failed";
 return reply({error:code},code==="unauthorized"?401:403);
}});
