#!/usr/bin/env python3
"""Prepare a private upload key without publishing or replacing any existing key.
Reference: https://developer.android.com/studio/publish/app-signing
"""
import os,secrets,subprocess,json,hashlib,base64,datetime
from pathlib import Path
os.umask(0o077)
root=Path(__file__).resolve().parents[1]
private=Path.home()/'Library/Application Support/Process Android Signing'
private.mkdir(mode=0o700,parents=True,exist_ok=True)
if private.stat().st_mode & 0o077:raise SystemExit('Signing directory must be private (0700). No keys changed.')
properties=private/'keystore.properties'
keystore=private/'process-upload.p12'
keytool=Path(os.environ.get('JAVA_HOME','/Applications/Android Studio.app/Contents/jbr/Contents/Home'))/'bin/keytool'
created=False
if properties.exists():
    if properties.stat().st_mode & 0o077:raise SystemExit('Signing properties must be private (0600). No keys changed.')
    values=dict(line.split('=',1) for line in properties.read_text().splitlines() if '=' in line and not line.startswith('#'))
    if Path(values.get('storeFile','')).resolve()!=keystore.resolve():raise SystemExit('Unexpected existing signing configuration. No keys changed.')
else:
    if keystore.exists():raise SystemExit('Existing key found without properties. Refusing to replace it.')
    password=secrets.token_urlsafe(48)
    values={'storeFile':str(keystore),'storePassword':password,'keyAlias':'process-upload','keyPassword':password}
    descriptor=os.open(properties,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(descriptor,'w') as file:file.write(''.join(f'{k}={v}\n' for k,v in values.items()))
env=os.environ.copy();env['PROCESS_UPLOAD_PASSWORD']=values['storePassword']
def run(arguments):
    result=subprocess.run([str(keytool)]+arguments,env=env,capture_output=True)
    if result.returncode:raise SystemExit('Signing tool failed. Existing files preserved; private credentials were not printed.')
    return result.stdout
if not keystore.exists():
    run(['-genkeypair','-keystore',str(keystore),'-storetype','PKCS12','-alias',values['keyAlias'],'-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=Process Android Upload','-storepass:env','PROCESS_UPLOAD_PASSWORD','-keypass:env','PROCESS_UPLOAD_PASSWORD'])
    created=True
os.chmod(keystore,0o600)
common=['-keystore',str(keystore),'-alias',values['keyAlias'],'-storepass:env','PROCESS_UPLOAD_PASSWORD']
der=run(['-exportcert']+common)
pem=run(['-exportcert','-rfc']+common)
certificate=root/'parity/upload-certificate.pem';certificate.write_bytes(pem)
metadata={'recordedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'created':created,'purpose':'Candidate Google Play upload key; not registered with Play App Signing','propertiesPath':str(properties),'keystorePath':str(keystore),'privateFileModes':{'directory':oct(private.stat().st_mode&0o777),'properties':oct(properties.stat().st_mode&0o777),'keystore':oct(keystore.stat().st_mode&0o777)},'keyAlias':values['keyAlias'],'publicCertificate':str(certificate),'sha1':':'.join(f'{b:02X}' for b in hashlib.sha1(der).digest()),'sha256':':'.join(f'{b:02X}' for b in hashlib.sha256(der).digest()),'releasePublished':False,'releaseBundleBuilt':False}
(root/'parity/upload-signing-validation.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(json.dumps({key:metadata[key] for key in ['created','purpose','propertiesPath','publicCertificate','privateFileModes','sha256']}))
