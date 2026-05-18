const app = document.createElement('main');
app.id = 'app';
app.className = 'hidden';
app.innerHTML = `
  <section class="sidebar">
    <h1>Character Selection</h1>
    <div id="cards" class="cards"></div>
    <div id="spawns" class="cards hidden"></div>
  </section>
  <section class="details">
    <h2 id="title">Select a character</h2>
    <pre id="details"></pre>
    <div class="actions" id="char-actions">
      <button id="play">Play</button>
      <button id="delete">Delete</button>
      <button id="create">Create</button>
    </div>
    <div class="actions hidden" id="spawn-actions">
      <button id="spawn-confirm">Spawn Here</button>
      <button id="spawn-back">Back</button>
    </div>
    <div class="token-wrap hidden" id="token-wrap">
      <label>Type server token to delete:</label>
      <input id="token" type="text" placeholder="Token" />
      <button id="token-confirm">Confirm Delete</button>
    </div>
  </section>`;
document.body.appendChild(app);

const state = { chars: [], active: null, spawns: [], selectedSpawn: null, spawnMode: false };
const $ = (id) => document.getElementById(id);

function nuiPost(name, data={}) { fetch(`https://${GetParentResourceName()}/${name}`, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(data) }); }
function renderChars(){ const el=$('cards'); el.innerHTML=''; state.chars.forEach(c=>{const n=document.createElement('article'); n.className='card'+(state.active&&state.active.cid===c.cid?' active':''); n.innerHTML=`<div class='name'>${c.name||'Unnamed'}</div><div class='meta'>${c.job||'Unemployed'}</div>`; n.onclick=()=>{state.active=c; $('token-wrap').classList.add('hidden'); renderChars(); renderDetails();}; el.appendChild(n);});}
function renderSpawns(){ const el=$('spawns'); el.innerHTML=''; state.spawns.forEach(s=>{const n=document.createElement('article'); n.className='card'+(state.selectedSpawn===s.id?' active':''); n.innerHTML=`<div class='name'>${s.label}</div><div class='meta'>${s.kind||'spawn'}</div>`; n.onclick=()=>{state.selectedSpawn=s.id; renderSpawns();}; el.appendChild(n);});}
function renderDetails(){ $('details').textContent = state.active ? JSON.stringify(state.active,null,2) : ''; $('title').textContent = state.spawnMode ? 'Select Spawn Location' : (state.active?.name || 'Select a character'); }
function toggleMode(spawnMode){ state.spawnMode=spawnMode; $('cards').classList.toggle('hidden', spawnMode); $('spawns').classList.toggle('hidden', !spawnMode); $('char-actions').classList.toggle('hidden', spawnMode); $('spawn-actions').classList.toggle('hidden', !spawnMode); renderDetails(); }

$('play').onclick=()=> state.active && nuiPost('selectCharacter',{cid:state.active.cid});
$('create').onclick=()=> nuiPost('createCharacter');
$('delete').onclick=()=> $('token-wrap').classList.remove('hidden');
$('token-confirm').onclick=()=> state.active && nuiPost('deleteCharacter',{cid:state.active.cid, token:$('token').value.trim()});
$('spawn-confirm').onclick=()=> state.selectedSpawn && nuiPost('selectSpawn',{spawnId:state.selectedSpawn});
$('spawn-back').onclick=()=> toggleMode(false);

window.addEventListener('message',(e)=>{
  const msg=e.data;
  if(msg.action==='open'){app.classList.remove('hidden'); state.chars=msg.payload?.characters||[]; state.active=state.chars[0]||null; $('token').value=''; $('token-wrap').classList.add('hidden'); toggleMode(false); renderChars(); renderDetails();}
  if(msg.action==='spawnPicker'){ state.spawns=msg.options||[]; state.selectedSpawn=state.spawns[0]?.id||null; renderSpawns(); toggleMode(true); }
});
