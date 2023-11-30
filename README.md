## Issue

1. Create `.env` file and add your RPC endpoint to `RPC_URL`:

```
# .env File

RPC_URL=<YOUR RPC URL HERE>
```

2. Run `make test`, it should revert due to UniV2 Reentrancy lock.