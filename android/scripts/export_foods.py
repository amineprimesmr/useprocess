#!/usr/bin/env python3
"""Convert only literal food declarations, rejecting unsupported Swift expressions."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'useprocess/WelcomePlan/Food/DebloatFoodCatalog.swift'
text=source.read_text()
def split(value):
 out=[];start=0;depth=0;quoted=False;escaped=False
 for i,c in enumerate(value):
  if quoted:
   if escaped:escaped=False
   elif c=='\\':escaped=True
   elif c=='"':quoted=False
  elif c=='"':quoted=True
  elif c in '[(':depth+=1
  elif c in '])':depth-=1
  elif c==',' and depth==0:out.append(value[start:i].strip());start=i+1
 out.append(value[start:].strip());return out
rows=[]
for m in re.finditer(r'\bfood\("',text):
 start=m.start()+len('food(');depth=1;quoted=False;escaped=False;end=start
 for end in range(start,len(text)):
  c=text[end]
  if quoted:
   if escaped:escaped=False
   elif c=='\\':escaped=True
   elif c=='"':quoted=False
  elif c=='"':quoted=True
  elif c=='(':depth+=1
  elif c==')':
   depth-=1
   if depth==0:break
 parts=split(text[start:end]);row={'id':json.loads(parts[0]),'name':json.loads(parts[1]),'category':parts[2][1:],'tier':parts[3][1:]}
 for field in parts[4:]:
  key,value=field.split(':',1);value=value.strip();key=key.strip()
  if key not in ['k','na','mg','why','tags','swaps','portion']:raise ValueError(key)
  row[key]=None if value=='nil' else json.loads(value)
 rows.append(row)
assert rows and len({r['id'] for r in rows})==len(rows)
def string(value):return json.dumps(value,ensure_ascii=False).replace('$','\\$')
def number(value):return 'null' if value is None else str(float(value))
def array(value):return 'listOf('+','.join(string(x) for x in value)+')'
lines=['package com.process.android','','// Generated from Process DebloatFoodCatalog.swift; do not edit data manually.','object DebloatFoods {',' val all:List<DebloatFood> = listOf(']
for r in rows:
 lines.append('  DebloatFood('+','.join([string(r['id']),string(r['name']),'FoodCategory.'+r['category'],'FoodTier.'+r['tier'],number(r['k']),number(r['na']),number(r['mg']),string(r['why']),array(r.get('tags',[])),array(r.get('swaps',[])),'null' if r.get('portion') is None else string(r['portion'])])+'),')
lines+=[' )',' private val byId=all.associateBy { it.id }',' fun item(id:String):DebloatFood?=byId[id]',' fun tier(tier:FoodTier)=all.filter { it.tier==tier }.sortedByDescending { it.score }',' fun search(query:String)=all.filter { FoodNames.normalize(it.name).contains(FoodNames.normalize(query)) }','}']
(ROOT/'android/app/src/main/java/com/process/android/DebloatFoods.kt').write_text('\n'.join(lines)+'\n')
(ROOT/'android/parity/food-data.json').write_text(json.dumps({'source':str(source.relative_to(ROOT)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'count':len(rows),'foods':rows},ensure_ascii=False,indent=2)+'\n')
print('Exported',len(rows),'original food records')
