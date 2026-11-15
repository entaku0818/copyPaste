package com.clipkit.prototype;

import java.util.ArrayList;
import java.util.List;

/** Pure retention policy; duplicates keep their original capture time. */
public final class HistoryPolicy {
    public static final int LIMIT = 20;
    public static final long AGE_MS = 3L * 24 * 60 * 60 * 1000;
    public static final int MAX_TEXT_LENGTH = 100_000;
    public static final class Entry {
        public final String text;
        public final long capturedAt;
        public Entry(String text, long capturedAt) { this.text = text; this.capturedAt = capturedAt; }
    }
    public static List<Entry> retain(List<Entry> source, long now) {
        List<Entry> result = new ArrayList<>();
        for (Entry e : source) {
            if (e.capturedAt > now || now - e.capturedAt >= AGE_MS || e.text.isEmpty()) continue;
            boolean duplicate = false;
            for (Entry kept : result) if (kept.text.equals(e.text)) duplicate = true;
            if (!duplicate && result.size() < LIMIT) result.add(e);
        }
        return result;
    }
    public static List<Entry> add(List<Entry> source, String text, boolean sensitive, long now) {
        List<Entry> result = retain(source, now);
        if (sensitive || text == null || text.trim().isEmpty() || text.length() > MAX_TEXT_LENGTH) return result;
        for (Entry e : result) if (e.text.equals(text)) return result;
        result.add(0, new Entry(text, now));
        return retain(result, now);
    }
    private HistoryPolicy() { }
}
