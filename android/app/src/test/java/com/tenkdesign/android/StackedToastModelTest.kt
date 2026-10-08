package com.tenkdesign.android
import org.junit.Test
import org.junit.Assert.*
class StackedToastModelTest {
 @Test fun sourceStackBounds() {assertEquals(StackedToastGeometry(0f,1f,25f),StackedToastModel.geometry(0,1));assertEquals(StackedToastGeometry(10f,.95f,12.5f),StackedToastModel.geometry(1,2));assertEquals(StackedToastGeometry(20f,.9f,0f),StackedToastModel.geometry(10,11))}
 @Test fun onlySourceLeftSwipeDismisses() {assertTrue(StackedToastModel.dismissGesture(-41f,0f));assertFalse(StackedToastModel.dismissGesture(-40f,0f));assertFalse(StackedToastModel.dismissGesture(50f,0f));assertFalse(StackedToastModel.dismissGesture(Float.NaN,0f))}
 @Test fun invalidTimeoutsDoNotCreateOverflowingTimers() {assertNull(StackedToastModel.autoDismissMs(null));assertNull(StackedToastModel.autoDismissMs(Double.NaN));assertNull(StackedToastModel.autoDismissMs(-1.0));assertEquals(5000L,StackedToastModel.autoDismissMs(5.0));assertEquals(Long.MAX_VALUE,StackedToastModel.autoDismissMs(Double.MAX_VALUE))}
}
