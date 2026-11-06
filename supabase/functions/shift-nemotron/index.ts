import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {createClient} from "npm:@supabase/supabase-js@2.78.0";

const env=(s:string)=>Deno.env.get(s)??"";
const trim=(v:unknown,n=1000)=>typeof v==="string"?v.trim().slice(0,n):"";
const obj=(v:unknown):Record<string,unknown>=>v&&typeof v==="object"&&!Array.isArray(v)?v as Record<string,unknown>:{};
const cors={"Content-Type":"application/json","Cache-Control":"no-store","Access-Control-Allow-Origin":"*",
 "Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info",
 "Access-Control-Allow-Methods":"POST,OPTIONS"};
const send=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:cors});
const MODEL="nvidia/nemotron-3.5-embed-1b";
const ENDPOINT="https://integrate.api.nvidia.com/v1/embeddings";
const service=()=>createClient(env("SUPABASE_URL"),env("SUPABASE_SERVICE_ROLE_KEY"),
 {auth:{persistSession:false,autoRefreshToken:false}});
const apiKey=()=>env("SHIFT_NVIDIA_NEMOTRON_EMBED_API_KEY")||env("SHIFT_NVIDIA_API_KEY");
async function actor(req:Request){
 const jwt=req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
 if(!jwt)throw Error("unauthorized");
 const caller=createClient(env("SUPABASE_URL"),env("SUPABASE_ANON_KEY"),{
  global:{headers:{Authorization:"Bearer "+jwt}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await caller.auth.getUser(jwt);
 if(error||!data.user)throw Error("unauthorized");
 const db=service();
 const {data:workspace}=await db.from("shift_workspaces").select("id")
  .eq("owner_id",data.user.id).single();
 if(!workspace)throw Error("workspace_not_found");
 return {db,workspaceId:String(workspace.id),uid:data.user.id};
}
async function vectorize(items:string[],mode:"passage"|"query"){
 const key=apiKey();
 if(!key)throw Error("embedding_not_configured");
 if(!items.length||items.length>8)throw Error("invalid_batch");
 const response=await fetch(ENDPOINT,{method:"POST",signal:AbortSignal.timeout(30000),
  headers:{"Content-Type":"application/json","Accept":"application/json",
   "Authorization":"Bearer "+key},
  body:JSON.stringify({model:MODEL,input:items,input_type:mode,
   modality:"text",truncate:"END",encoding_format:"float",embedding_type:"float",dimensions:1024})});
 if(response.status===401||response.status===403)throw Error("embedding_credentials_rejected");
 if(response.status===429)throw Error("embedding_rate_limited");
 if(!response.ok)throw Error("embedding_provider_unavailable");
 let data:any;
 try{data=await response.json()}catch{throw Error("embedding_invalid_response")}
 const rows=Array.isArray(data.data)?data.data.slice().sort((a:any,b:any)=>a.index-b.index):[];
 if(rows.length!==items.length)throw Error("embedding_invalid_response");
 return rows.map((entry:any)=>{
  const vector=entry.embedding;
  if(!Array.isArray(vector)||vector.length!==1024||
    !vector.every((v:unknown)=>typeof v==="number"&&Number.isFinite(v)))
    throw Error("embedding_invalid_response");
  return vector as number[];
 });
}
type Source={type:string;id:string;title:string;url:string;snippet:string};
async function sources(db:ReturnType<typeof service>,wid:string){
 const [{data:bookmarks,error:be},{data:research,error:re}]=await Promise.all([
  db.from("shift_research_bookmarks").select("id,topic,url,notes,publisher")
   .eq("workspace_id",wid).order("saved_at",{ascending:false}).limit(30),
  db.from("shift_research_sources").select("id,title,url,summary,publisher")
   .eq("workspace_id",wid).order("fetched_at",{ascending:false}).limit(30)
 ]);
 if(be||re)throw Error("knowledge_source_error");
 const byId=new Map<string,Source>();
 for(const row of bookmarks??[]){
  const title=trim(row.topic,400),snippet=trim(row.notes,3000)||title;
  const item={type:"bookmark",id:String(row.id),title,url:trim(row.url,1800),snippet};
  if(title&&item.url)byId.set(item.type+":"+item.id,item);
 }
 for(const row of research??[]){
  const title=trim(row.title,400),snippet=trim(row.summary,3000)||title;
  const item={type:"research",id:String(row.id),title,url:trim(row.url,1800),snippet};
  if(title&&item.url)byId.set(item.type+":"+item.id,item);
 }
 return [...byId.values()].slice(0,60);
}
async function sha(text:string){
 const bytes=new TextEncoder().encode(text);
 const dig=await crypto.subtle.digest("SHA-256",bytes);
 return [...new Uint8Array(dig)].map(x=>x.toString(16).padStart(2,"0")).join("");
}
async function indexKnowledge(db:ReturnType<typeof service>,wid:string){
 const existing=await sources(db,wid);
 if(!existing.length)return {indexed:0,unchanged:0,total:0};
 const {data:old,error}=await db.from("shift_knowledge_embeddings")
  .select("source_type,source_id,content_hash").eq("workspace_id",wid).eq("model_id",MODEL).limit(100);
 if(error)throw Error("knowledge_storage_error");
 const hashes=new Map((old??[]).map(x=>[x.source_type+":"+x.source_id,x.content_hash]));
 const changed:Array<{doc:Source;content:string;digest:string}>=[];
 for(const item of existing){
  const content=("Title: "+item.title+"\nContent: "+item.snippet).slice(0,3500);
  const digest=await sha(content);
  if(hashes.get(item.type+":"+item.id)!==digest)changed.push({doc:item,content,digest});
 }
 const batch=changed.slice(0,32);
 for(let i=0;i<batch.length;i+=8){
  const chunk=batch.slice(i,i+8);
  const vectors=await vectorize(chunk.map(x=>x.content),"passage");
  const values=chunk.map((x,n)=>({
   workspace_id:wid,source_type:x.doc.type,source_id:x.doc.id,model_id:MODEL,
   title:x.doc.title,snippet:x.doc.snippet,source_url:x.doc.url,content_hash:x.digest,
   embedding:"["+vectors[n].join(",")+"]",updated_at:new Date().toISOString()
  }));
  const {error:saveError}=await db.from("shift_knowledge_embeddings").upsert(values,{
   onConflict:"workspace_id,source_type,source_id,model_id"});
  if(saveError)throw Error("knowledge_storage_error");
 }
 return {indexed:batch.length,unchanged:existing.length-changed.length,total:existing.length,remaining:changed.length-batch.length};
}
async function handle(req:Request){
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
 if(req.method!=="POST")return send({error:"method_not_allowed"},405);
 const user=await actor(req);
 let body:Record<string,unknown>;
 try{body=obj(await req.json())}catch{return send({error:"invalid_json"},400)}
 const action=trim(body.action,30);
 if(action==="status"){
  const configured=!!apiKey();
  const {count,error}=await user.db.from("shift_knowledge_embeddings")
   .select("id",{count:"exact",head:true})
   .eq("workspace_id",user.workspaceId).eq("model_id",MODEL);
  return send({configured,model:MODEL,type:"embedding",dimensions:1024,
   indexedCount:error?null:count,provider:"nvidia",keyLocation:"Supabase Edge Function secrets",
   capableOfTextGeneration:false,liveInferenceVerified:false});
 }
 if(action==="index"){
  if(!apiKey())return send({error:"embedding_not_configured"},503);
  const result=await indexKnowledge(user.db,user.workspaceId);
  return send({status:"indexed",...result});
 }
 if(action==="search"){
  if(!apiKey())return send({error:"embedding_not_configured"},503);
  const query=trim(body.query,600);
  if(query.length<3)return send({error:"invalid_query"},400);
  const [vector]=await vectorize([query],"query");
  const {data,error}=await user.db.rpc("shift_match_knowledge",{
   p_workspace:user.workspaceId,p_model:MODEL,p_query_text:"["+vector.join(",")+"]",p_limit:8
  });
  if(error)throw Error("knowledge_search_error");
  const matches=(data??[]).map((v:any)=>({
   sourceType:v.source_type,sourceId:v.source_id,title:v.title,
   snippet:v.snippet,url:v.source_url,score:Math.max(0,Math.min(1,Number(v.similarity)||0))
  }));
  return send({model:MODEL,query,matches,note:"Semantic similarity is not evidence of source accuracy."});
 }
 return send({error:"unknown_action"},400);
}
Deno.serve(async req=>{
 try{return await handle(req)}
 catch(error){
  const code=error instanceof Error?error.message:"embedding_failed";
  const allowed=["unauthorized","workspace_not_found","embedding_not_configured",
   "embedding_credentials_rejected","embedding_rate_limited","embedding_provider_unavailable",
   "embedding_invalid_response","invalid_batch","knowledge_source_error",
   "knowledge_storage_error","knowledge_search_error","too_many_sources"];
  const safe=allowed.includes(code)?code:"embedding_failed";
  console.error("SHIFT Nemotron",{error:safe});
  return send({error:safe},safe==="unauthorized"?401:
   safe==="embedding_rate_limited"?429:
   safe==="embedding_not_configured"?503:502);
 }
});
