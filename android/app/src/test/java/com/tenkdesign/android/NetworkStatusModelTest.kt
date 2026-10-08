package com.tenkdesign.android

import org.junit.Assert.*
import org.junit.Test

class NetworkStatusModelTest {
    @Test fun startupUnknownDoesNotTrapUserInOfflineModal() {
        assertFalse(NetworkStatus().showOffline)
        assertTrue(NetworkStatus(false).showOffline)
        assertFalse(NetworkStatus(unavailable=true).showOffline)
    }
    @Test fun pathAvailabilityDoesNotPretendInternetValidation() {
        val captivePortal=NetworkStatus(true,NetworkTransport.WIFI,validated=false)
        assertFalse(captivePortal.showOffline)
        assertFalse(captivePortal.validated)
    }
    @Test fun originalInterfacePrioritySurvivesMultipleTransports() {
        assertEquals(NetworkTransport.WIFI,NetworkStatusModel.preferredTransport(setOf(NetworkTransport.WIFI,NetworkTransport.VPN,NetworkTransport.CELLULAR)))
        assertEquals(NetworkTransport.CELLULAR,NetworkStatusModel.preferredTransport(setOf(NetworkTransport.ETHERNET,NetworkTransport.CELLULAR)))
        assertNull(NetworkStatusModel.preferredTransport(emptySet()))
    }
}
