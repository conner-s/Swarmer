-- Tests for swarm_file.lua
-- Tests file operations (using test directory to avoid affecting real files)

local TestFramework = require("tests.test_framework")
local SwarmFile = require("lib.swarm_file")

local TEST_DIR = "tests/test_files"
local function runTests()
    TestFramework.reset()
    
    -- Clean up test directory before starting
    if fs.exists(TEST_DIR) then
        -- Remove test files
        local files = fs.list(TEST_DIR)
        for _, file in ipairs(files) do
            local path = fs.combine(TEST_DIR, file)
            if not fs.isDir(path) then
                fs.delete(path)
            end
        end
    end
    
    local tests = {
        -- Test ensureDirectory
        ["ensureDirectory creates directory"] = function()
            local testPath = fs.combine(TEST_DIR, "test_dir")
            if fs.exists(testPath) then
                fs.delete(testPath)
            end
            local result = SwarmFile.ensureDirectory(testPath)
            TestFramework.assertTrue(result, "Should create directory")
            TestFramework.assertTrue(fs.exists(testPath), "Directory should exist")
            TestFramework.assertTrue(fs.isDir(testPath), "Should be a directory")
        end,
        
        ["ensureDirectory returns true for existing directory"] = function()
            local testPath = fs.combine(TEST_DIR, "existing_dir")
            SwarmFile.ensureDirectory(testPath)
            local result = SwarmFile.ensureDirectory(testPath)
            TestFramework.assertTrue(result, "Should return true for existing directory")
        end,
        
        -- Test writeFile and readFile
        ["writeFile creates file"] = function()
            local testPath = fs.combine(TEST_DIR, "test_write.txt")
            local content = "Test content"
            local success, err = SwarmFile.writeFile(testPath, content)
            TestFramework.assertTrue(success, "Should write file successfully")
            TestFramework.assertNil(err, "Should not return error")
        end,
        
        ["readFile reads file content"] = function()
            local testPath = fs.combine(TEST_DIR, "test_read.txt")
            local expected = "Hello, World!"
            SwarmFile.writeFile(testPath, expected)
            local content, err = SwarmFile.readFile(testPath)
            TestFramework.assertNotNil(content, "Should read file content")
            TestFramework.assertNil(err, "Should not return error")
            TestFramework.assertEqual(content, expected, "Should match written content")
        end,
        
        ["readFile returns error for non-existent file"] = function()
            local content, err = SwarmFile.readFile("nonexistent_file.txt")
            TestFramework.assertNil(content, "Should return nil for missing file")
            TestFramework.assertNotNil(err, "Should return error message")
            TestFramework.assertTrue(err:find("not found") ~= nil, "Error should mention file not found")
        end,
        
        -- Test splitIntoChunks and assembleChunks
        ["splitIntoChunks splits content correctly"] = function()
            local content = string.rep("a", 10000) -- 10k characters
            local chunks = SwarmFile.splitIntoChunks(content, 1000)
            TestFramework.assertType(chunks, "table", "Should return table")
            TestFramework.assertTrue(#chunks > 1, "Should create multiple chunks")
        end,
        
        ["assembleChunks reconstructs content"] = function()
            local original = "Test content for chunking"
            local chunks = SwarmFile.splitIntoChunks(original, 5)
            local reconstructed = SwarmFile.assembleChunks(chunks)
            TestFramework.assertEqual(reconstructed, original, "Should reconstruct original content")
        end,
        
        ["splitIntoChunks uses default chunk size"] = function()
            local content = string.rep("a", SwarmFile.CHUNK_SIZE * 2)
            local chunks = SwarmFile.splitIntoChunks(content)
            TestFramework.assertEqual(#chunks, 2, "Should create 2 chunks with default size")
        end,
        
        -- Test logStep
        ["logStep function exists"] = function()
            TestFramework.assertNotNil(SwarmFile.logStep, "logStep function should exist")
            TestFramework.assertType(SwarmFile.logStep, "function", "logStep should be a function")
        end,
        
        -- Test backupFile (requires existing file)
        ["backupFile creates backup"] = function()
            local testFile = fs.combine(TEST_DIR, "backup_test.txt")
            SwarmFile.writeFile(testFile, "Backup test content")
            local backupPath, err = SwarmFile.backupFile(testFile, fs.combine(TEST_DIR, "backups"))
            TestFramework.assertNotNil(backupPath, "Should create backup file")
            TestFramework.assertNil(err, "Should not return error")
            TestFramework.assertTrue(fs.exists(backupPath), "Backup file should exist")
        end,
        
        ["backupFile returns error for non-existent file"] = function()
            local backupPath, err = SwarmFile.backupFile("nonexistent.txt")
            TestFramework.assertNil(backupPath, "Should return nil for missing file")
            TestFramework.assertNotNil(err, "Should return error message")
        end,
        
        -- Test findFiles
        ["findFiles returns table"] = function()
            local sourceFiles, missing = SwarmFile.findFiles({"nonexistent.lua"})
            TestFramework.assertType(sourceFiles, "table", "Should return table for sourceFiles")
            TestFramework.assertType(missing, "table", "Should return table for missing")
        end,
        
        -- Test CHUNK_SIZE constant
        ["CHUNK_SIZE is defined"] = function()
            TestFramework.assertNotNil(SwarmFile.CHUNK_SIZE, "CHUNK_SIZE should be defined")
            TestFramework.assertType(SwarmFile.CHUNK_SIZE, "number", "CHUNK_SIZE should be a number")
        end,
    }
    
    -- Ensure test directory exists
    SwarmFile.ensureDirectory(TEST_DIR)
    
    return TestFramework.runSuite("swarm_file", tests)
end

return {
    run = runTests
}

