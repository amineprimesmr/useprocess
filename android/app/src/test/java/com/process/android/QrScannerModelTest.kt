package com.process.android
import org.junit.Test
import org.junit.Assert.*
class QrScannerModelTest {
 @Test fun returnsFirstCodeOnlyWithoutInterpretingUrl(){val gate=QrCodeDelivery();assertNull(gate.accept(null));assertEquals("https://example.test/untrusted",gate.accept("https://example.test/untrusted"));assertNull(gate.accept("another"))}
 @Test fun closedRequestCannotDeliverLateResult(){val gate=QrCodeDelivery();gate.close();assertNull(gate.accept("late"))}
}
