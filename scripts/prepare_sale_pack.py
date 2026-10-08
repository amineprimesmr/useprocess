#!/usr/bin/env python3
"""Create a private Process-only preparation snapshot, never a customer-data export."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, tarfile
parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);args=parser.parse_args()
root=Path(__file__).resolve().parents[1];out=Path(args.output).expanduser().resolve()
if out.exists() or out==root or root in out.parents:raise SystemExit('Choose a new directory outside the checkout')
roots=['useprocess','Shared','ProcessWidgets','useprocess.xcodeproj','website-process/src','website-process/public','firebase/functions/src','firebase/functions/test','metadata']
files=['Info.plist','firebase.json','firestore.rules','firestore.indexes.json','storage.rules','.firebaserc','firebase/functions/package.json','firebase/functions/package-lock.json','firebase/functions/tsconfig.json']
files += ['website-process/'+n for n in ['package.json','package-lock.json','vite.config.js','vercel.json','index.html','affiliate.html','clipping.html','.env.example']]
files += ['docs/cession/2026-10-07/'+n for n in ['PASSATION_TECHNIQUE.txt','CONTROLES_AVANT_VALIDATION.txt','VALIDATION_IPHONE.txt','NOTES_REVIEW_BROUILLON.txt','PROCEDURE_TRANSFERT.txt','PERIMETRE_CESSION.txt','CONFIGURATION_ET_EXPLOITATION.txt','REGISTRE_PASSATION.json','REGISTRE_DROITS_CONTENUS.json','COUTS_ET_PREUVES_A_COMPLETER.csv']]
skipdirs={'.git','node_modules','dist','build','lib','.vercel','xcuserdata','__pycache__','.DS_Store'}
private=re.compile(rb'(?:sk_live_|sk_test_|sk-ant-|whsec_)[A-Za-z0-9_-]{16,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|"type"\s*:\s*"service_account"')
candidates=set()
for name in roots:
 p=root/name
 if p.exists():candidates.update(x for x in p.rglob('*') if x.is_file())
for name in files:
 p=root/name
 if p.is_file():candidates.add(p)
out.mkdir(parents=True,mode=0o700);manifest=[];excluded=[];transformed=[];media=[]
for p in sorted(candidates):
 rel=p.relative_to(root);n=p.name;reason=None
 if p.is_symlink():reason='symlink'
 elif any(x in skipdirs for x in rel.parts):reason='generated or personal state'
 elif n.startswith('.') and n not in {'.firebaserc','.env.example'}:reason='hidden local state'
 elif n.startswith('.env') and n!='.env.example':reason='live environment'
 elif p.suffix.lower() in {'.p8','.p12','.mobileprovision','.key','.pem','.log','.pyc'}:reason='credential or generated file'
 elif ('Secrets.plist' in n and not n.endswith('.example')) or n=='GoogleService-Info.plist':reason='live client configuration supplied separately'
 if reason:excluded.append({'path':str(rel),'reason':reason});continue
 data=p.read_bytes()
 if private.search(data):excluded.append({'path':str(rel),'reason':'private credential pattern; review required'});continue
 if str(rel)=='useprocess/Analytics/AppsFlyerConfiguration.swift':
  data=re.sub(rb'(static let devKey\s*=\s*)"[^"]*"',rb'\1"YOUR_APPSFLYER_DEV_KEY"',data)
  transformed.append({'path':str(rel),'reason':'account-scoped AppsFlyer client key replaced in snapshot only'})
 dest=out/'sources'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
 manifest.append({'path':str(rel),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
 if p.suffix.lower() in {'.png','.jpg','.jpeg','.webp','.gif','.mp4','.mov','.mp3','.wav','.ttf','.otf','.woff','.woff2'}:media.append({'path':str(rel),'status':'ownership or transferable licence proof required'})
(out/'MANIFEST.json').write_text(json.dumps({'status':'INTERNAL_PREPARATION_NOT_APPROVED_FOR_HANDOFF','buyer':None,'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'working_tree_snapshot':True,'files':manifest,'excluded':excluded,'transformed':transformed,'media_rights_pending':len(media),'excluded_scope':['old website','other projects','git history','raw cloud audit','billing records','user databases','private backups','signing assets']},indent=2,ensure_ascii=False)+'\n')
(out/'MEDIA_RIGHTS_PENDING.json').write_text(json.dumps(media,indent=2)+'\n')
(out/'LIRE_AVANT_REMISE.txt').write_text('PACK INTERNE — PAS ENCORE AUTORISÉ À ÊTRE LIVRÉ\nÉtat de travail actuel, sans historique Git, sauvegardes privées ni export utilisateurs.\nConfigurations Firebase/RevenueCat/PostHog et clé AppsFlyer à configurer séparément.\nLes médias restent soumis aux justificatifs de propriété/licence listés dans MEDIA_RIGHTS_PENDING.json.\nLe code de préparation peut différer de l’IPA actuel : figer après tests physiques.\nAucun transfert, upload Apple, soumission ou retrait vendeur exécuté.\n')
archive=out/'process-debloat-preparation.tar.gz'
with tarfile.open(archive,'w:gz') as tf:
 for child in sorted(out.iterdir()):
  if child!=archive:tf.add(child,arcname=child.name)
digest=hashlib.sha256(archive.read_bytes()).hexdigest();(out/'SHA256SUMS.txt').write_text(digest+'  '+archive.name+'\n')
print(json.dumps({'output':str(out),'files':len(manifest),'bytes':sum(x['bytes'] for x in manifest),'excluded':len(excluded),'transformed':len(transformed),'media_pending':len(media),'archive_sha256':digest}))
