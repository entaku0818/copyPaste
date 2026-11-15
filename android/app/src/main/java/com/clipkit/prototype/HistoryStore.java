package com.clipkit.prototype;

import android.content.Context;
import android.util.AtomicFile;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

final class HistoryStore {
    private final AtomicFile file;
    HistoryStore(Context context) { file = new AtomicFile(new File(context.getFilesDir(), "history.json")); }
    synchronized List<HistoryPolicy.Entry> read() {
        List<HistoryPolicy.Entry> entries = new ArrayList<>();
        try {
            JSONArray array = new JSONArray(new String(file.readFully(), StandardCharsets.UTF_8));
            for (int i = 0; i < array.length(); i++) {
                JSONObject e = array.getJSONObject(i);
                entries.add(new HistoryPolicy.Entry(e.getString("text"), e.getLong("capturedAt")));
            }
        } catch (java.io.FileNotFoundException ignored) {
            // No history on first launch.
        } catch (IOException | org.json.JSONException ignored) {
            // Fail closed on corrupt local data; never log clipboard contents.
        }
        List<HistoryPolicy.Entry> retained = HistoryPolicy.retain(entries, System.currentTimeMillis());
        if (retained.size() != entries.size()) write(retained);
        return retained;
    }
    synchronized boolean add(String text, boolean sensitive) {
        return write(HistoryPolicy.add(read(), text, sensitive, System.currentTimeMillis()));
    }
    synchronized boolean clear() { return write(new ArrayList<>()); }
    private boolean write(List<HistoryPolicy.Entry> entries) {
        FileOutputStream stream = null;
        try {
            JSONArray array = new JSONArray();
            for (HistoryPolicy.Entry e : entries) {
                JSONObject object = new JSONObject();
                object.put("text", e.text); object.put("capturedAt", e.capturedAt); array.put(object);
            }
            stream = file.startWrite();
            stream.write(array.toString().getBytes(StandardCharsets.UTF_8));
            file.finishWrite(stream);
            return true;
        } catch (IOException | org.json.JSONException ignored) {
            if (stream != null) file.failWrite(stream);
            return false;
        }
    }
}
