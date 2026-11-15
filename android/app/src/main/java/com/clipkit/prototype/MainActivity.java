package com.clipkit.prototype;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

public final class MainActivity extends Activity {
    private LinearLayout root;
    @Override public void onCreate(Bundle state) { super.onCreate(state); }
    @Override public void onResume() { super.onResume(); render(); }
    private void render() {
        ScrollView scroll = new ScrollView(this); root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setPadding(24, 48, 24, 24); root.setOnApplyWindowInsetsListener((view, insets) -> {
            android.graphics.Insets bars = android.os.Build.VERSION.SDK_INT >= 30
                ? insets.getInsets(android.view.WindowInsets.Type.systemBars())
                : android.graphics.Insets.of(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(), insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            view.setPadding(24 + bars.left, 24 + bars.top, 24 + bars.right, 24 + bars.bottom);
            return insets;
        }); scroll.addView(root); setContentView(scroll);
        text("ClipKit Android 最小試作\n端末内のみ • テキスト専用 • 20件 / 直近3日\n画像・同期・課金は未対応。機密フラグ付きコピーは保存しません。\n標準IMEでも停止中のコピーは取りこぼします。別IME選択中は保存しません。\nキーボードを有効化後、入力欄でClipKitを選択してください。試作キーはabc・空白・削除・改行のみです。");
        text("現在のIME: " + Settings.Secure.getString(getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD));
        button("1. キーボード設定", () -> startActivity(new Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)));
        button("2. IMEを選択", () -> getSystemService(InputMethodManager.class).showInputMethodPicker());
        button("更新", this::render);
        button("履歴を全削除", () -> new AlertDialog.Builder(this).setMessage("端末内の履歴をすべて削除しますか？").setPositiveButton("削除", (d, w) -> {
            if (!new HistoryStore(this).clear()) new AlertDialog.Builder(this).setMessage("削除できませんでした").setPositiveButton("OK", null).show();
            render();
        }).setNegativeButton("キャンセル", null).show());
        for (HistoryPolicy.Entry entry : new HistoryStore(this).read()) text(entry.text + "\n" + new java.util.Date(entry.capturedAt));
    }
    private void text(String value) { TextView view = new TextView(this); view.setText(value); view.setTextSize(16); root.addView(view); }
    private void button(String label, Runnable action) { Button view = new Button(this); view.setText(label); view.setOnClickListener(v -> action.run()); root.addView(view); }
}
