# Swarmer Test Suite

This directory contains automated tests for the Swarmer project to help prevent regressions and ensure functionality is maintained.

## Running Tests

To run all tests, execute:

```lua
tests/run_tests
```

Or from within Lua:

```lua
require("tests.run_tests")
```

## Test Structure

### Test Framework (`test_framework.lua`)

The test framework provides assertion utilities and test running functionality:

- `assert(condition, message)` - Basic assertion
- `assertEqual(actual, expected, message)` - Check equality
- `assertNotEqual(actual, expected, message)` - Check inequality
- `assertNil(value, message)` - Check for nil
- `assertNotNil(value, message)` - Check for non-nil
- `assertType(value, expectedType, message)` - Check type
- `assertTrue(value, message)` - Check for true
- `assertFalse(value, message)` - Check for false
- `assertError(func, message)` - Check that function raises error
- `assertNoError(func, message)` - Check that function doesn't raise error

### Test Suites

Each library module has its own test suite:

- `test_swarm_common.lua` - Tests for `lib/swarm_common.lua`
- `test_swarm_file.lua` - Tests for `lib/swarm_file.lua`
- `test_swarm_config.lua` - Tests for `lib/swarm_config.lua`
- `test_swarm_gps.lua` - Tests for `lib/swarm_gps.lua`
- `test_swarm_ui.lua` - Tests for `lib/swarm_ui.lua`

## Writing New Tests

To add tests for a new module or extend existing tests:

1. Create a test file following the pattern `test_<module_name>.lua`
2. Use the test framework's assertion functions
3. Return a table with a `run` function that executes all tests
4. Add the test suite to `run_tests.lua`

Example test file structure:

```lua
local TestFramework = require("tests.test_framework")
local MyModule = require("lib.my_module")

local function runTests()
    TestFramework.reset()
    
    local tests = {
        ["test name"] = function()
            -- Test code here
            TestFramework.assertEqual(MyModule.function(), expected)
        end,
    }
    
    return TestFramework.runSuite("my_module", tests)
end

return {
    run = runTests
}
```

## Test Coverage

Current test coverage includes:

- **swarm_common**: Message creation, validation utilities, timestamp formatting, error handling
- **swarm_file**: File operations, directory management, chunking utilities
- **swarm_config**: JSON serialization, configuration loading/saving, nested key access
- **swarm_gps**: Position formatting, GPS utilities
- **swarm_ui**: Response buffer, menu system, UI components

## Notes

- Tests that require peripherals (modem, GPS, monitor) may be skipped or have limited coverage
- File operations use a test directory (`tests/test_files`) to avoid affecting real files
- Configuration tests use a separate test config directory (`tests/test_config`)

