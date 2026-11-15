package com.clipkit.fixture;
import android.app.Instrumentation;
import android.os.*;
import android.graphics.Rect;
import android.view.*;
import android.view.accessibility.*;
import android.accessibilityservice.AccessibilityServiceInfo;
import org.json.JSONArray;
import java.io.FileInputStream;
import java.nio.charset.StandardCharsets;
/** Emulator-only test. UI automation privileges are never used by the product. */
public final class PrototypeRunner extends Instrumentation {
    static final String IME="com.clipkit.prototype/.ClipKitIme";
    String original; StringBuilder report=new StringBuilder();
    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
    @Override public void onStart() {
        int code=-1;
        try {
            if (!shell("getprop ro.kernel.qemu").trim().equals("1")) throw new AssertionError("Emulator only");
            original=shell("settings get secure default_input_method").trim();
            AccessibilityServiceInfo info=getUiAutomation().getServiceInfo(); info.flags|=AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS; getUiAutomation().setServiceInfo(info);
            launch("roundtrip",false,true); shell("ime enable "+IME); shell("ime set "+IME);
            launch("roundtrip",false,false); click("Copy test text"); SystemClock.sleep(7000);
            check(has("roundtrip"),"other-app copy saved with IME visible");
            click("roundtrip"); pause(); check(find("roundtrip","android.widget.EditText")!=null,"history tap commitText reached independent editor");
            click("abc"); pause(); check(find("roundtripabc","android.widget.EditText")!=null,"minimum key commitText");
            shell("input keyevent BACK"); pause(); click("Copy test text"); pause(); check(size()==1,"duplicate external recopy suppressed");
            launch("hidden-copy",false,false); click("Test destination"); pause(); shell("input keyevent BACK"); pause(); click("Copy test text"); pause(); check(has("hidden-copy"),"IME hidden copy saved while service alive");
            launch("sensitive-never-save",true,true); pause(); check(!has("sensitive-never-save"),"sensitive clip excluded");
            launch("persistent-marker",false,true); pause(); check(has("persistent-marker"),"persistent history before process stop");
            shell("am force-stop com.clipkit.prototype"); line("Default after force-stop: "+shell("settings get secure default_input_method").trim()); launch("missed-intermediate",false,true); pause(); check(!has("missed-intermediate"),"stopped process misses callbacks");
            launch("latest-after-stop",false,true); pause(); shell("ime set "+IME);
            shell("am start -n com.clipkit.prototype/.MainActivity"); pause(); launch("no-copy",false,false); pause();
            check(has("persistent-marker"),"history survives process recreation"); check(has("latest-after-stop"),"recreated default IME catches current clip"); check(!has("missed-intermediate"),"intermediate copy while stopped is unrecoverable");
            shell("ime set "+original); pause(); launch("other-ime-copy",false,true); pause(); check(!has("other-ime-copy"),"other default IME no automatic capture");
            shell("ime set "+IME); launch("no-copy",false,false); pause(); check(has("other-ime-copy"),"reselect catches current clip only");
            for(int i=0;i<23;i++) launch("limit-"+i,false,true);
            check(size()==20 && has("limit-22") && !has("limit-0"),"device retention capped at newest 20");
            shell("am start -n com.clipkit.prototype/.MainActivity"); pause(); click("履歴を全削除"); pause(); click("削除"); pause(); check(size()==0,"delete all persists empty history");
            shell("am force-stop com.clipkit.prototype"); shell("am start -n com.clipkit.prototype/.MainActivity"); shell("ime set "+IME); pause(); launch("no-copy",false,false); pause(); check(size()==0,"deletion survives recreation without current clip reimport");
            launch("rebind-marker",false,true); pause();
            String pid=shell("pidof com.clipkit.prototype").trim();
            shell("am crash com.clipkit.prototype"); SystemClock.sleep(2500); line("Default after crash: "+shell("settings get secure default_input_method").trim());
            launch("rebind-current",false,true); pause();
            check(has("rebind-marker"),"durable history survives abrupt process death");
            check(has("rebind-current"),"system rebind captures after process death");
            String newPid=shell("pidof com.clipkit.prototype").trim(); check(!newPid.isEmpty() && !pid.equals(newPid),"process PID changed after crash"); line("Process recreated: "+pid+" -> "+newPid);
            line("ALL INTEGRATION CHECKS PASSED");
        } catch(Throwable e) { code=0; line("FAIL: "+e); }
        finally { if(original!=null) try { shell("ime set "+original); line("Restored emulator IME: "+original); } catch(Exception e) {code=0;line("Restore failed: "+e);} }
        Bundle result=new Bundle(); result.putString("stream",report.toString()); finish(code,result);
    }
    void launch(String text,boolean sensitive,boolean auto) throws Exception { shell("am start -n com.clipkit.fixture/.EditorActivity -f 0x10008000 --es text "+text+" --ez sensitive "+sensitive+" --ez autoCopy "+auto); SystemClock.sleep(1300); }
    void pause(){SystemClock.sleep(900);}
    JSONArray data() throws Exception {String raw=shell("run-as com.clipkit.prototype cat files/history.json").trim(); return raw.contains("No such file")?new JSONArray():new JSONArray(raw);}
    int size() throws Exception{return data().length();}
    boolean has(String text) throws Exception {JSONArray a=data();for(int i=0;i<a.length();i++)if(text.equals(a.getJSONObject(i).getString("text")))return true;return false;}
    String shell(String cmd) throws Exception {try(ParcelFileDescriptor fd=getUiAutomation().executeShellCommand(cmd);FileInputStream in=new FileInputStream(fd.getFileDescriptor())){return new String(in.readAllBytes(),StandardCharsets.UTF_8);}}
    void check(boolean ok,String label){if(!ok)throw new AssertionError(label);line("PASS: "+label);}
    void line(String value){report.append(value).append('\n');Bundle b=new Bundle();b.putString("stream",value+"\n");sendStatus(0,b);}
    AccessibilityNodeInfo find(String text,String cls){for(AccessibilityWindowInfo w:getUiAutomation().getWindows()){AccessibilityNodeInfo n=walk(w.getRoot(),text,cls);if(n!=null)return n;}return null;}
    AccessibilityNodeInfo walk(AccessibilityNodeInfo n,String text,String cls){if(n==null)return null;if(text.contentEquals(n.getText()==null?"":n.getText())&&(cls==null||cls.contentEquals(n.getClassName())))return n;for(int i=0;i<n.getChildCount();i++){AccessibilityNodeInfo found=walk(n.getChild(i),text,cls);if(found!=null)return found;}return null;}
    void click(String text){AccessibilityNodeInfo n=null;for(int i=0;i<15&&n==null;i++){n=find(text,null);if(n==null)SystemClock.sleep(200);}if(n==null)throw new AssertionError("UI text missing: "+text);Rect b=new Rect();n.getBoundsInScreen(b);long now=SystemClock.uptimeMillis();for(int action:new int[]{MotionEvent.ACTION_DOWN,MotionEvent.ACTION_UP}){MotionEvent e=MotionEvent.obtain(now,SystemClock.uptimeMillis(),action,b.centerX(),b.centerY(),0);e.setSource(InputDevice.SOURCE_TOUCHSCREEN);getUiAutomation().injectInputEvent(e,true);e.recycle();}SystemClock.sleep(300);}
}
