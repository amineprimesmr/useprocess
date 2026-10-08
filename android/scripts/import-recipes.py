#!/usr/bin/env python3
"""Import current Process catalog literals and original asset bytes, never legacy ignored scores."""
from pathlib import Path
import re,json,textwrap,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2];IOS=ROOT/'useprocess';ANDROID=ROOT/'android'
paths=[IOS/'WelcomePlan'/n for n in ['ProcessDebloatMealLibrary.swift','ProcessLocalizedMealNames.swift','ProcessLocalizedMealContentCatalog.swift']]
source=paths[0].read_text();translations='\n'.join(p.read_text() for p in paths[1:])
string=r'"""[\s\S]*?"""|"(?:\\.|[^"\\])*"'
def decoded(s):
 if s.startswith('"""'):return textwrap.dedent(s[3:-3]).strip()
 return json.loads(s)
def normalized(s):return ' '.join(s.split())
maps={}
for name in ['mealNamesFRToEN','mealTipsFRToEN','mealSummariesFRToEN','mealPrepsFRToEN','itemNamesFRToEN','quantitiesFRToEN','ingredientQuantitiesFRToEN']:
 match=re.search(r'static let '+name+r': \[String: String\] = \[(.*?)\n    \]',translations,re.S);assert match,name
 maps[name]={normalized(decoded(k)):decoded(v) for k,v in re.findall('('+string+r')\s*:\s*('+string+')',match[1])}
def pair(value,mapname,required=True):
 key=normalized(value)
 if required:assert key in maps[mapname],(mapname,value)
 return [value,maps[mapname].get(key,value)]
def block_at(start):
 depth=0;i=start
 while i<len(source):
  if source[i]=='"':m=re.match(string,source[i:]);assert m;i+=len(m.group());continue
  if source[i]=='(':depth+=1
  elif source[i]==')':
   depth-=1
   if depth==0:return source[start:i+1]
  i+=1
 raise ValueError('Unbalanced Swift call')
recipes=[];assets={};missingTranslations=[]
for match in re.finditer(r'\bmakeMeal\(\s*name:\s*"',source):
 block=block_at(source.index('(',match.start()))
 def field(name):
  m=re.search(r'\b'+name+r':\s*('+string+')',block);assert m,name;return decoded(m.group(1))
 name=field('name');image=field('image');slot=re.search(r'\bslot:\s*\.(\w+)',block).group(1)
 section=re.findall(r'private static let (\w+)Meals:',source[:match.start()])[-1]
 items=[]
 for parts in re.findall(r'\bitem\(\s*('+string+r')\s*,\s*('+string+r')\s*,\s*('+string+r')\s*\)',block):
  n,q,role=map(decoded,parts)
  quantityEn=maps['quantitiesFRToEN'].get(normalized(q),maps['ingredientQuantitiesFRToEN'].get(normalized(q),q))
  items.append({'name':pair(n,'itemNamesFRToEN'),'quantity':[q,quantityEn],'role':role})
 assert items
 recipe={'id':image,'name':pair(name,'mealNamesFRToEN'),'slot':slot,'section':section,'summary':pair(field('summary'),'mealSummariesFRToEN'),'ingredients':items,'prepMinutes':int(re.search(r'prepMinutes:\s*(\d+)',block).group(1)),'preparation':pair(field('prep'),'mealPrepsFRToEN'),'tip':pair(field('tip'),'mealTipsFRToEN'),'image':image}
 assert all('\\(' not in text for key in ['name','summary','preparation','tip'] for text in recipe[key])
 recipes.append(recipe)
 candidates=list((IOS/'Assets.xcassets').rglob(image+'.imageset/Contents.json'));assert len(candidates)==1,(image,candidates)
 meta=json.loads(candidates[0].read_text());file=next(i['filename'] for i in meta['images'] if i.get('filename'))
 original=candidates[0].parent/file;data=original.read_bytes();ext='.jpg' if data[:2]==b'\xff\xd8' else '.png';assert data[:2]==b'\xff\xd8' or data.startswith(b'\x89PNG')
 dest=ANDROID/'app/src/main/res/drawable-nodpi'/('recipe_'+image+ext);dest.write_bytes(data)
 assets[image]={'source':str(original),'native':str(dest),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
assert len(recipes)==18,len(recipes)
assert len({r['id'] for r in recipes})==len(recipes)
def q(s):return json.dumps(s,ensure_ascii=False).replace('$','\\$')
def kp(p):return 'RecipeCopy('+q(p[0])+','+q(p[1])+')'
lines=['package com.process.android','','// Generated from live Process; legacy score/sub arguments are ignored by the source factory.','object ProcessRecipeCatalog {',' val meals=listOf(']
for r in recipes:
 ingredients='listOf('+','.join('RecipeIngredient('+kp(i['name'])+','+kp(i['quantity'])+','+q(i['role'])+')' for i in r['ingredients'])+')'
 lines.append('  ProcessRecipe('+','.join([q(r['id']),kp(r['name']),q(r['slot']),q(r['section']),kp(r['summary']),ingredients,str(r['prepMinutes']),kp(r['preparation']),kp(r['tip']),'R.drawable.recipe_'+r['image']])+'),')
lines+=[' )',' fun forSlot(slot:String)=meals.filter {it.slot==slot}','}']
(ANDROID/'app/src/main/java/com/process/android/ProcessRecipeCatalog.kt').write_text('\n'.join(lines)+'\n')
proof={'sourceSha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},'recipeCount':len(recipes),'recipes':recipes,'assets':assets,'scores':'Legacy score/sub arguments deliberately omitted; current Swift makeMeal ignores them','build':'pending'}
(ANDROID/'parity/recipe-source.json').write_text(json.dumps(proof,indent=2,ensure_ascii=False)+'\n');print('Imported',len(recipes),'bilingual recipes and',len(assets),'original images')
