# Perpetual Futures Market Smart Contract

A decentralized perpetual futures market implementation built with Clarity for the Stacks blockchain.

## Overview

This smart contract implements a simple perpetual futures trading platform that allows users to:
- Open leveraged long/short positions using STX as collateral
- Close positions with PnL settlement
- Participate in liquidations of under-margined positions
- Access price feed data managed by admin

## Features

- **Collateral Management**: STX-based collateral system
- **Leverage**: Configurable leverage for both long and short positions
- **Price Feed**: Admin-controlled price oracle integration
- **Risk Management**: 
  - 5% maintenance margin requirement
  - Liquidation mechanism for under-margined positions
  - 10% liquidator reward system
- **Fees**: 0.5% protocol fee on profitable trades

## Technical Specifications

### Constants
- `SCALE`: 1e6 (fixed-point precision)
- `MAINTENANCE_MARGIN`: 5%
- `PROTOCOL_FEE`: 0.5%
- `LIQUIDATOR_REWARD`: 10%

### Key Functions

```clarity
(define-public (open-position (side bool) (collateral uint) (leverage uint)))
(define-public (close-position (position-id uint)))
(define-public (liquidate (position-id uint)))
(define-read-only (view-position-pnl (id uint)))
```

## Security Features

- Admin-controlled price feed
- Checked arithmetic operations
- Protected transfer functions
- Position ownership verification
- Comprehensive error handling

## Error Codes

- `ERR-NOT-ADMIN (100)`: Unauthorized admin action
- `ERR-INVALID-LEVERAGE (102)`: Invalid leverage value
- `ERR-INSUFFICIENT-COLLATERAL (103)`: Insufficient collateral
- `ERR-POSITION-NOT-FOUND (104)`: Position doesn't exist
- `ERR-NOT-OWNER (105)`: Unauthorized position access
- Additional error codes for various validation checks

## Development

### Prerequisites
- Clarity CLI
- Stacks blockchain local development environment

### Testing
To be implemented:
- Unit tests for position management
- Integration tests for liquidation scenarios
- Price feed update testing
- Admin control testing

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Disclaimer

This is a prototype implementation and should not be used in production without thorough security auditing.

---
*Note: This is an experimental smart contract. Use at your own risk.*
