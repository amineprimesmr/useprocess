#!/usr/bin/env python3
"""Serialized, low-priority Android builds; preserve caches and responsiveness."""
import fcntl,os,subprocess,sys,time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
arguments=sys.argv[1:]
wait_for_slot=arguments[:1]==['--wait']
if wait_for_slot:arguments=arguments[1:]
if arguments[:1]==['--project-root']:
    if len(arguments)<3:sys.exit('Usage: build.py --project-root /path gradle-task...')
    root=Path(arguments[1]).resolve();arguments=arguments[2:]
    if not (root/'gradlew').is_file():sys.exit('Project has no Gradle wrapper.')
lock=Path.home()/'Library/Caches/10kdesign-device/android-build.lock'
lock.parent.mkdir(parents=True,exist_ok=True)
with lock.open('a') as handle:
    deadline=time.monotonic()+300
    reported=None
    while True:
        locked=False
        reason=None
        try:
            fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB);locked=True
        except BlockingIOError:
            reason='Another managed Android build is running.'
        if locked:
            for pattern in ['GradleWrapperMain','xcodebuild']:
                matches=subprocess.run(['pgrep','-f',pattern],capture_output=True,text=True).stdout.split()
                for pid in matches:
                    # Confirm a compiler executable, not a read-only search shell.
                    command=subprocess.run(['ps','-p',pid,'-o','comm='],capture_output=True,text=True).stdout.strip()
                    executable=Path(command).name
                    if executable in ({'java','javaw'} if pattern=='GradleWrapperMain' else {'xcodebuild'}):
                        reason=f'Another compilation is running ({pattern}, PID {pid}); retry after it finishes.'
                        break
                if reason:break
        if reason is None:break
        if locked:fcntl.flock(handle,fcntl.LOCK_UN)
        if not wait_for_slot or time.monotonic()>=deadline:sys.exit(reason)
        if reason!=reported:print('Waiting for build slot: '+reason,flush=True);reported=reason
        time.sleep(5)
    env=os.environ.copy()
    env.setdefault('JAVA_HOME','/Applications/Android Studio.app/Contents/jbr/Contents/Home')
    env.setdefault('ANDROID_HOME',str(Path.home()/'Library/Android/sdk'))
    sys.exit(subprocess.call(['nice','-n','15',str(root/'gradlew'),'--no-daemon','--max-workers=1']+arguments,cwd=root,env=env))
