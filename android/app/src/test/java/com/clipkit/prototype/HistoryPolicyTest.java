package com.clipkit.prototype;
import org.junit.Test;
import java.util.ArrayList;
import java.util.List;
import static org.junit.Assert.*;
public class HistoryPolicyTest {
    @Test public void newestTwentyAndDuplicateDoesNotExtendRetention() {
        List<HistoryPolicy.Entry> list = new ArrayList<>();
        for (int i = 0; i < 25; i++) list = HistoryPolicy.add(list, "item" + i, false, 100 + i);
        assertEquals(20, list.size()); assertEquals("item24", list.get(0).text);
        list = HistoryPolicy.add(list, "item24", false, 200);
        assertEquals(20, list.size()); assertEquals(124, list.get(0).capturedAt);
    }
    @Test public void expiryBoundaryAndClockRollbackFailClosed() {
        List<HistoryPolicy.Entry> list = List.of(new HistoryPolicy.Entry("expired", 100), new HistoryPolicy.Entry("valid", 101), new HistoryPolicy.Entry("future", Long.MAX_VALUE));
        List<HistoryPolicy.Entry> kept = HistoryPolicy.retain(list, 100 + HistoryPolicy.AGE_MS);
        assertEquals(1, kept.size()); assertEquals("valid", kept.get(0).text);
    }
    @Test public void rejectsSensitiveEmptyAndOversizedText() {
        List<HistoryPolicy.Entry> list = new ArrayList<>();
        assertTrue(HistoryPolicy.add(list, "secret", true, 1).isEmpty());
        assertTrue(HistoryPolicy.add(list, " \n", false, 1).isEmpty());
        assertTrue(HistoryPolicy.add(list, null, false, 1).isEmpty());
        assertTrue(HistoryPolicy.add(list, "x".repeat(100001), false, 1).isEmpty());
    }
}
