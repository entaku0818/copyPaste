package com.clipkit.fixture;
import android.app.Activity;
import android.os.Bundle;
import android.os.PersistableBundle;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.widget.*;
/** Separate, test-only app. No production dependencies or privileged clipboard access. */
public final class EditorActivity extends Activity {
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout root = new LinearLayout(this); root.setPadding(20, 60, 20, 20); root.setOrientation(LinearLayout.VERTICAL);root.setOnApplyWindowInsetsListener((view, insets) -> {
            android.graphics.Insets bars = android.os.Build.VERSION.SDK_INT >= 30
                ? insets.getInsets(android.view.WindowInsets.Type.systemBars())
                : android.graphics.Insets.of(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(), insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            view.setPadding(20 + bars.left, 20 + bars.top, 20 + bars.right, 20 + bars.bottom);
            return insets;
        });
        TextView title = new TextView(this); title.setText("Independent test editor"); root.addView(title);
        EditText editor = new EditText(this); editor.setContentDescription("Test destination"); editor.setHint("Test destination"); root.addView(editor);
        Button copy = new Button(this); copy.setText("Copy test text"); copy.setAllCaps(false); root.addView(copy);
        copy.setOnClickListener(v -> publish()); setContentView(root); editor.requestFocus();
        if (getIntent().getBooleanExtra("autoCopy", false)) root.postDelayed(this::publish, 700);
    }
    private void publish() {
        String value = getIntent().getStringExtra("text"); if (value == null) value = "clipkit-roundtrip";
        ClipData data = ClipData.newPlainText("fixture", value);
        if (getIntent().getBooleanExtra("sensitive", false)) {
            PersistableBundle extras = new PersistableBundle(); extras.putBoolean("android.content.extra.IS_SENSITIVE", true); data.getDescription().setExtras(extras);
        }
        getSystemService(ClipboardManager.class).setPrimaryClip(data);
    }
}
