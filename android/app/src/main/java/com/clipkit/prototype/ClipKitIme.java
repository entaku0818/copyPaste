package com.clipkit.prototype;

import android.content.ClipData;
import android.content.ClipDescription;
import android.content.ClipboardManager;
import android.inputmethodservice.InputMethodService;
import android.provider.Settings;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

public final class ClipKitIme extends InputMethodService {
    private ClipboardManager clipboard;
    private HistoryStore store;
    private LinearLayout history;
    private final ClipboardManager.OnPrimaryClipChangedListener listener = this::capture;
    @Override public void onCreate() {
        super.onCreate();
        store = new HistoryStore(this);
        clipboard = getSystemService(ClipboardManager.class);
        clipboard.addPrimaryClipChangedListener(listener);
        capture();
    }
    private void capture() {
        // Explicitly stop collection when another IME is selected, even if this service survives.
        String selected = Settings.Secure.getString(getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD);
        if (selected == null || !selected.startsWith(getPackageName() + "/")) return;
        try {
            ClipDescription description = clipboard.getPrimaryClipDescription();
            if (description == null) return;
            boolean sensitive = description.getExtras() != null && description.getExtras().getBoolean("android.content.extra.IS_SENSITIVE", false);
            if (sensitive || !description.hasMimeType("text/*")) return;
            ClipData clip = clipboard.getPrimaryClip();
            if (clip == null || clip.getItemCount() != 1) return;
            // Another app can replace the clip between the two binder calls.
            // Re-check the actual returned clip before reading/persisting its text.
            description = clip.getDescription();
            if (description.getExtras() != null && description.getExtras().getBoolean("android.content.extra.IS_SENSITIVE", false)) return;
            if (!description.hasMimeType("text/*")) return;
            ClipData.Item item = clip.getItemAt(0);
            // Never resolve URI/Intent content or fetch remote data.
            if (item.getUri() != null || item.getIntent() != null || item.getText() == null) return;
            String text = item.getText().toString();
            if (text.length() > HistoryPolicy.MAX_TEXT_LENGTH || text.trim().isEmpty()) return;
            String fingerprint = description.getTimestamp() + ":" + digest(text);
            android.content.SharedPreferences prefs = getSharedPreferences("capture", MODE_PRIVATE);
            if (fingerprint.equals(prefs.getString("lastSeen", ""))) return;
            if (store.add(text, false)) prefs.edit().putString("lastSeen", fingerprint).commit();
            refresh();
        } catch (SecurityException ignored) {
            // Clipboard eligibility can change during an IME switch.
        }
    }
    private static String digest(String text) {
        try {
            byte[] bytes = MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8));
            StringBuilder result = new StringBuilder();
            for (byte b : bytes) result.append(String.format(java.util.Locale.ROOT, "%02x", b & 255));
            return result.toString();
        } catch (java.security.NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
    }
    @Override public View onCreateInputView() {
        LinearLayout root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(8, 8, 8, 8); root.setOnApplyWindowInsetsListener((view, insets) -> {
            android.graphics.Insets bars = android.os.Build.VERSION.SDK_INT >= 30
                ? insets.getInsets(android.view.WindowInsets.Type.systemBars())
                : android.graphics.Insets.of(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(), insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            view.setPadding(8 + bars.left, 8 + bars.top, 8 + bars.right, 8 + bars.bottom);
            return insets;
        }); root.setBackgroundColor(0xffeeeeee);
        TextView label = new TextView(this); label.setText("ClipKit • テキスト履歴（20件 / 3日）"); root.addView(label);
        ScrollView scroll = new ScrollView(this); history = new LinearLayout(this); history.setOrientation(LinearLayout.VERTICAL);
        scroll.addView(history); root.addView(scroll, new LinearLayout.LayoutParams(-1, 360));
        LinearLayout keys = new LinearLayout(this);
        key(keys, "abc", () -> commit("abc")); key(keys, "空白", () -> commit(" "));
        key(keys, "削除", () -> { if (getCurrentInputConnection() != null) getCurrentInputConnection().deleteSurroundingText(1, 0); });
        key(keys, "改行", () -> commit("\n"));
        key(keys, "IME切替", () -> getSystemService(InputMethodManager.class).showInputMethodPicker()); root.addView(keys);
        refresh(); return root;
    }
    private void key(LinearLayout row, String label, Runnable action) {
        Button button = new Button(this); button.setText(label); button.setAllCaps(false);
        button.setOnClickListener(v -> action.run()); row.addView(button, new LinearLayout.LayoutParams(0, -2, 1));
    }
    private void commit(String text) { if (getCurrentInputConnection() != null) getCurrentInputConnection().commitText(text, 1); }
    private void refresh() {
        if (history == null) return;
        history.removeAllViews();
        for (HistoryPolicy.Entry entry : store.read()) {
            Button button = new Button(this); button.setAllCaps(false); button.setText(entry.text); button.setMaxLines(2);
            button.setOnClickListener(v -> {
                // Re-check expiry if the keyboard has remained open for a long time.
                for (HistoryPolicy.Entry current : store.read()) {
                    if (current.text.equals(entry.text)) { commit(current.text); break; }
                }
                refresh();
            }); history.addView(button);
        }
        if (history.getChildCount() == 0) { TextView empty = new TextView(this); empty.setText("履歴なし • 他のアプリでテキストをコピー"); history.addView(empty); }
    }
    @Override public void onStartInput(EditorInfo info, boolean restarting) { super.onStartInput(info, restarting); capture(); }
    @Override public void onStartInputView(EditorInfo info, boolean restarting) { super.onStartInputView(info, restarting); capture(); refresh(); }
    @Override public boolean onEvaluateFullscreenMode() { return false; }
    @Override public void onDestroy() { clipboard.removePrimaryClipChangedListener(listener); super.onDestroy(); }
}
