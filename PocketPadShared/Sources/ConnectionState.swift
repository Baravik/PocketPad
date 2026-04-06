// ConnectionState.swift
// PocketPadShared

import Foundation

/// Represents the current connection state between iPhone and Mac
public enum ConnectionState: String, Codable {
    case disconnected
    case discovering
    case connecting
    case connected
    case reconnecting

    public var displayName: String {
        switch self {
        case .disconnected:  return "Disconnected"
        case .discovering:   return "Searching…"
        case .connecting:    return "Connecting…"
        case .connected:     return "Connected"
        case .reconnecting:  return "Reconnecting…"
        }
    }

    public var isActive: Bool {
        switch self {
        case .connected, .reconnecting: return true
        default: return false
        }
    }

    public var systemImageName: String {
        switch self {
        case .disconnected:  return "wifi.slash"
        case .discovering:   return "magnifyingglass"
        case .connecting:    return "wifi.exclamationmark"
        case .connected:     return "wifi"
        case .reconnecting:  return "arrow.clockwise"
        }
    }
}
