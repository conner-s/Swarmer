# ComputerCraft Turtle Swarm Management System

## Senior Engineer Production Deployment Guide

This system provides enterprise-grade turtle fleet management with automated deployment, version control, health monitoring, and recovery capabilities.

## System Overview

### Components

- **worker_simple.lua** - Simplified worker for basic deployments
- **worker_production.lua** - Enterprise-grade worker with enhanced features
- **puppetmaster_simple.lua** - Control interface (simplified)
- **deploy.lua** - Automated deployment script
- **fleet_manager.lua** - Bulk operations and health monitoring
- **update_manager.lua** - Version tracking and updates

### Architecture

```text
    Puppetmaster          Fleet Manager         Update Manager
         |                      |                      |
         |                      |                      |
    [Wireless Modem] ---- [Wireless Modem] ---- [Wireless Modem]
         |                      |                      |
         v                      v                      v
    ┌─────────────────────────────────────────────────────────┐
    │                Turtle Fleet Network                      │
    │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
    │  │Turtle #1│  │Turtle #2│  │Turtle #3│  │Turtle #N│     │
    │  │Worker   │  │Worker   │  │Worker   │  │Worker   │     │
    │  └─────────┘  └─────────┘  └─────────┘  └─────────┘     │
    └─────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Setup Your Pocket Computer

On your Pocket Computer (or control computer):

```bash
# Essential files for deployment:
- install.lua          # Self-contained installer (includes worker)
- distribute.lua       # Helper for distribution
- puppetmaster_simple.lua  # Control interface
- fleet_manager.lua    # Bulk operations (optional)
```

### 2. Deploy Worker to Turtles

#### **Recommended Method: Floppy Disk Transfer**

On your Pocket Computer:

```bash
# Copy installer to disk
cp install.lua disk/install.lua
```

On each turtle:

```bash
# Copy from disk and run
cp disk/install.lua install.lua
install.lua
# Press 'y' to install
# Press 'y' to reboot
```

**Alternative: Manual Edit (for single turtle)**

```bash
# On turtle
edit install.lua
# Paste the content from install.lua
# Save and run
install.lua
```

The installer will:

- Backup existing `startup.lua`
- Install embedded worker code as `worker.lua`
- Create auto-starting `startup.lua`
- Set up directory structure (`programs/`, `backups/`)
- Add version tracking

### 3. Verify Deployment

From your control computer:

```bash
# Start puppetmaster
puppetmaster_simple.lua

# Test connectivity
Option 2: Ping all turtles
# You should see: "✓ Turtle #X: Pong from turtle #X"
```

## Production Features

### Worker Production Edition (`worker_production.lua`)

Enhanced features for enterprise deployment:

#### Error Handling & Logging

- Comprehensive error logging to `error.log`
- Automatic error recovery mechanisms
- Critical error detection and recovery
- Transaction logging for all operations

#### Resource Management

- Memory monitoring and garbage collection
- Session limits (max 10 concurrent)
- Fuel level monitoring and alerts
- Working directory management per session

#### Security Features

- Command validation (blocks dangerous commands)
- Session isolation
- Input sanitization
- Safe program execution environment

#### Health Monitoring

- Automatic heartbeat transmission
- System resource reporting
- GPS position tracking
- Startup health checks

#### Performance Optimizations

- Efficient output capture
- Retry mechanisms for network operations
- Session cleanup and resource management
- Background health monitoring

### Fleet Management (`fleet_manager.lua`)

Bulk operations for production environments:

#### Fleet Discovery

- Auto-discover all turtles on network
- Health status monitoring
- Real-time status reporting

#### Bulk Operations

- Send commands to entire fleet
- Targeted operations on specific turtles
- Emergency recovery procedures
- Fleet status exports

#### Health Monitoring

- Continuous fleet health monitoring
- Alert system for unresponsive turtles
- Performance metrics collection

### Update Management (`update_manager.lua`)

Version control and update deployment:

#### Version Tracking

- Fleet-wide version reporting
- Version distribution analysis
- Deployment history tracking

#### Update Deployment

- Automated update distribution
- Rollback capabilities
- Update verification
- Batch update operations

#### Recovery Features

- Force redeploy for corrupted installations
- Backup management
- Emergency recovery procedures

## Best Practices

### 1. Pre-Deployment Checklist

- [ ] Verify modem installation on all turtles
- [ ] Test network connectivity
- [ ] Backup existing turtle configurations
- [ ] Prepare deployment packages
- [ ] Document turtle locations and purposes

### 2. Deployment Process

1. **Test Environment**: Deploy to 1-2 turtles first
2. **Staged Rollout**: Deploy in batches of 5-10 turtles
3. **Validation**: Verify each batch before proceeding
4. **Documentation**: Record deployment status and issues

### 3. Monitoring and Maintenance

- **Daily**: Check fleet health status
- **Weekly**: Review error logs and performance
- **Monthly**: Update to latest worker version
- **Quarterly**: Full backup and disaster recovery test

### 4. Troubleshooting Guide

#### Turtle Not Responding

1. Check modem installation
2. Verify channel configuration
3. Check fuel levels
4. Review error logs
5. Force redeploy if necessary

#### Performance Issues

1. Check memory usage (fleet_manager)
2. Review session counts
3. Analyze error patterns
4. Consider worker restart

#### Network Issues

1. Verify channel settings
2. Check for interference
3. Test range limitations
4. Review modem configurations

## Configuration

### Channel Settings

- **COMMAND_CHANNEL**: 100 (puppetmaster → workers)
- **REPLY_CHANNEL**: 101 (workers → puppetmaster)

### Resource Limits

- **MAX_SESSIONS**: 10 per worker
- **HEARTBEAT_INTERVAL**: 30 seconds
- **UPDATE_TIMEOUT**: 10 seconds

### File Structure

```
turtle/
├── startup.lua              # Auto-start worker
├── worker_simple.lua        # Worker code
├── .worker_version          # Version tracking
├── error.log               # Error logging
├── backups/                # Backup directory
│   ├── startup.lua.backup
│   └── worker_simple.lua.*
└── programs/               # User programs
    ├── digDown.lua
    └── ...
```

## Recovery Procedures

### Emergency Recovery

If workers become unresponsive:

1. **Use Fleet Manager**:

   ```bash
   fleet_manager.lua
   # Option 6: Emergency recovery
   ```

2. **Manual Recovery**:
   - Create `.recovery_mode` file on turtle
   - Reboot turtle
   - Worker will not auto-start
   - Fix issues manually

3. **Force Redeploy**:

   ```bash
   update_manager.lua
   # Option 4: Force redeploy
   ```

### Rollback Procedure

If updates fail:

1. **Automatic Rollback**:

   ```bash
   update_manager.lua
   # Option 3: Rollback update
   ```

2. **Manual Rollback**:
   - Copy from `backups/` directory
   - Replace current worker
   - Reboot turtle

## Security Considerations

### Network Security

- Use dedicated channels for fleet communication
- Monitor for unauthorized access
- Implement channel rotation if needed

### Command Security

- Built-in dangerous command blocking
- Input validation and sanitization
- Session isolation

### Data Protection

- Regular backup procedures
- Error log rotation
- Secure storage of deployment scripts

## Performance Monitoring

### Key Metrics

- **Response Time**: Command acknowledgment speed
- **Error Rate**: Failed operations per hour
- **Resource Usage**: Memory and session utilization
- **Network Health**: Message success rates

### Monitoring Tools

- Fleet health dashboard (fleet_manager)
- Error log analysis
- Version distribution tracking
- Performance trend analysis

## Scaling Considerations

### Fleet Size Limits

- Tested with up to 50 turtles
- Network bandwidth considerations
- Channel congestion monitoring

### Performance Optimization

- Batch operations for large fleets
- Staggered update deployments
- Load balancing across channels

## Support and Troubleshooting

### Common Issues

#### "No modem found" Error

- Install wireless modem on turtle
- Verify peripheral detection
- Check for conflicts with other peripherals

#### Session Creation Failures

- Check session limits (max 10)
- Verify memory availability
- Review error logs for details

#### Update Deployment Failures

- Verify network connectivity
- Check available disk space
- Ensure worker is running

### Advanced Diagnostics

#### Debug Mode

Enable debug mode in puppetmaster for detailed logging:

```lua
local DEBUG_COMMANDS = true
```

#### Error Log Analysis

Review `error.log` on workers for:

- Critical vs warning errors
- Error frequency patterns
- Resource exhaustion issues

#### Network Analysis

Monitor for:

- Message loss rates
- Response time degradation
- Channel interference

## Version History

### v2.2 (Production Release)

- Enhanced error handling and logging
- Resource monitoring and management
- Security improvements
- Performance optimizations
- Health monitoring system

### v2.1 (Simplified Release)

- Streamlined codebase (42% reduction)
- Improved user experience
- Simplified deployment
- Better output capture

### v2.0 (Multishell Release)

- Multishell support
- Multiple session management
- Enhanced remote shell

## Contributing

### Development Guidelines

- Follow production coding standards
- Comprehensive error handling required
- Performance impact assessment
- Security review for all changes

### Testing Requirements

- Unit testing for critical functions
- Integration testing with fleet
- Performance regression testing
- Security vulnerability assessment

## License

This software is provided as-is for ComputerCraft environments. Use at your own risk in production environments.
