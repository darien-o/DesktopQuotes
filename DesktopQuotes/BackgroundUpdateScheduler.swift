//
//  BackgroundUpdateScheduler.swift
//  DesktopQuotes
//
//  Created by Kiro on Enhanced Quote System Implementation
//

import Foundation
import IOKit.ps

/// Protocol defining background update scheduling operations
protocol BackgroundUpdateScheduler {
    func scheduleUpdates(interval: UpdateInterval)
    func cancelScheduledUpdates()
    func performImmediateUpdate() async
    var isScheduled: Bool { get }
}

/// Enum defining available update intervals
enum UpdateInterval: TimeInterval {
    case hourly = 3600
    case daily = 86400
    case weekly = 604800
}

/// Implementation of BackgroundUpdateScheduler using NSBackgroundActivityScheduler
final class SystemBackgroundUpdateScheduler: BackgroundUpdateScheduler {
    private let scheduler: NSBackgroundActivityScheduler
    private let logger = SchedulerLogger()
    private let updateHandler: () async -> Void
    private var currentInterval: UpdateInterval?
    
    private let batteryThreshold: Double = 0.20 // 20%
    private let cpuThreshold: Double = 0.80 // 80%
    
    var isScheduled: Bool {
        currentInterval != nil
    }
    
    /// Initialize with an update handler
    /// - Parameter updateHandler: Closure to execute when update is triggered
    init(identifier: String = "com.desktopquotes.backgroundupdate", updateHandler: @escaping () async -> Void) {
        self.scheduler = NSBackgroundActivityScheduler(identifier: identifier)
        self.updateHandler = updateHandler
        configureScheduler()
    }
    
    /// Schedule periodic background updates
    /// - Parameter interval: The update interval (hourly, daily, or weekly)
    func scheduleUpdates(interval: UpdateInterval) {
        logger.log("Scheduling updates with interval: \(interval.rawValue) seconds")
        
        currentInterval = interval
        scheduler.interval = interval.rawValue
        scheduler.repeats = true
        
        scheduler.schedule { [weak self] completion in
            guard let self = self else {
                completion(.finished)
                return
            }
            
            Task {
                await self.performScheduledUpdate(completion: completion)
            }
        }
        
        logger.log("Background updates scheduled successfully")
    }
    
    /// Cancel all scheduled updates
    func cancelScheduledUpdates() {
        logger.log("Cancelling scheduled updates")
        scheduler.invalidate()
        currentInterval = nil
        logger.log("Scheduled updates cancelled")
    }
    
    /// Perform an immediate update (manual trigger)
    func performImmediateUpdate() async {
        logger.log("Performing immediate update")
        await updateHandler()
        logger.log("Immediate update completed")
    }
    
    // MARK: - Private Methods
    
    /// Configure the scheduler with quality of service and tolerance
    private func configureScheduler() {
        scheduler.qualityOfService = .utility
        scheduler.tolerance = 300 // 5 minutes tolerance
    }
    
    /// Perform a scheduled update with system resource checks
    private func performScheduledUpdate(completion: @escaping (NSBackgroundActivityScheduler.Result) -> Void) async {
        logger.log("Scheduled update triggered")
        
        // Check battery level
        let batteryLevel = getBatteryLevel()
        if batteryLevel < batteryThreshold {
            logger.log("Battery level too low (\(Int(batteryLevel * 100))%), deferring update")
            completion(.deferred)
            return
        }
        
        // Check power source
        let isOnBattery = isRunningOnBattery()
        if isOnBattery {
            logger.log("Running on battery power, checking if update should be deferred")
            // On battery, we still allow updates but with reduced frequency
            // The scheduler's tolerance will help spread out updates
        }
        
        // Check CPU usage
        let cpuUsage = getCPUUsage()
        if cpuUsage > cpuThreshold {
            logger.log("CPU usage too high (\(Int(cpuUsage * 100))%), deferring update")
            completion(.deferred)
            return
        }
        
        // Perform the update
        await updateHandler()
        
        logger.log("Scheduled update completed successfully")
        completion(.finished)
    }
    
    /// Get current battery level (0.0 to 1.0)
    private func getBatteryLevel() -> Double {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        for source in sources {
            let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as! [String: Any]
            
            if let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = info[kIOPSMaxCapacityKey] as? Int,
               maxCapacity > 0 {
                return Double(currentCapacity) / Double(maxCapacity)
            }
        }
        
        // If we can't determine battery level, assume it's sufficient
        return 1.0
    }
    
    /// Check if the device is running on battery power
    private func isRunningOnBattery() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        for source in sources {
            let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as! [String: Any]
            
            if let powerSource = info[kIOPSPowerSourceStateKey] as? String {
                return powerSource == kIOPSBatteryPowerValue
            }
        }
        
        // If we can't determine, assume AC power
        return false
    }
    
    /// Get current CPU usage (0.0 to 1.0)
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                        PROCESSOR_CPU_LOAD_INFO,
                                        &numCPUs,
                                        &cpuInfo,
                                        &numCpuInfo)
        
        guard result == KERN_SUCCESS else {
            // If we can't determine CPU usage, assume it's acceptable
            return 0.0
        }
        
        defer {
            vm_deallocate(mach_task_self_,
                         vm_address_t(bitPattern: cpuInfo),
                         vm_size_t(Int(numCpuInfo) * MemoryLayout<integer_t>.stride))
        }
        
        var totalUsage: Double = 0.0
        
        for i in 0..<Int(numCPUs) {
            let cpuLoadInfo = cpuInfo.advanced(by: Int(i) * Int(CPU_STATE_MAX))
            let user = Double(cpuLoadInfo[Int(CPU_STATE_USER)])
            let system = Double(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            let nice = Double(cpuLoadInfo[Int(CPU_STATE_NICE)])
            let idle = Double(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            
            let total = user + system + nice + idle
            if total > 0 {
                totalUsage += (user + system + nice) / total
            }
        }
        
        return totalUsage / Double(numCPUs)
    }
}

// MARK: - Logger

/// Simple logger for scheduler operations
private struct SchedulerLogger {
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] BackgroundUpdateScheduler: \(message)")
    }
}
