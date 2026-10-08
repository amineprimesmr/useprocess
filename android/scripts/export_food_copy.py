#!/usr/bin/env python3
"""Export original literal FR/EN food dictionaries, without translating new copy."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'useprocess/WelcomePlan/Food/ProcessLocalizedDebloatFoodContent.swift'
text=source.read_text();maps={}
quoted=r'"(?:\\.|[^"\\])*"'
for name in ['namesFRToEN','whyFRToEN','portionHintsFRToEN','groceryQuantityFRToEN']:
 match=re.search(r'static let '+name+r': \[String: String\] = \[(.*?)\n    \]',text,re.S)
 if not match:raise ValueError(f'Missing dictionary {name}')
 pairs=re.findall('('+quoted+r')\s*:\s*('+quoted+')',match[1]);values={json.loads(k):json.loads(v) for k,v in pairs}
 if len(pairs)!=len(values):raise ValueError('Duplicate translation key')
 maps[name]=values
required={r['id'] for r in json.loads((ROOT/'android/parity/food-data.json').read_text())['foods']}
assert required<=maps['namesFRToEN'].keys(),required-maps['namesFRToEN'].keys()
assert required<=maps['whyFRToEN'].keys(),required-maps['whyFRToEN'].keys()
def q(v):return json.dumps(v,ensure_ascii=False).replace('$','\\$')
lines=['package com.process.android','','// Generated from ProcessLocalizedDebloatFoodContent.swift.','object FoodCopy {']
for name,values in maps.items():
 lines.append(' private val '+name+' = mapOf(')
 lines += ['  '+q(k)+' to '+q(v)+',' for k,v in values.items()]
 lines.append(' )')
lines += [' fun name(food:DebloatFood,english:Boolean)=if(english) namesFRToEN[food.id] ?: food.name else food.name',
 ' fun why(food:DebloatFood,english:Boolean)=if(english) whyFRToEN[food.id] ?: food.why else food.why',
 ' fun portion(value:String,english:Boolean)=if(english) portionHintsFRToEN[value] ?: groceryQuantityFRToEN[value] ?: value else value',
 '}']
(ROOT/'android/app/src/main/java/com/process/android/FoodCopy.kt').write_text('\n'.join(lines)+'\n')
(ROOT/'android/parity/food-copy.json').write_text(json.dumps({'source':str(source.relative_to(ROOT)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'counts':{k:len(v) for k,v in maps.items()}},indent=2)+'\n')
print({k:len(v) for k,v in maps.items()})
