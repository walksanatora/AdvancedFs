## Creating A custom File system
to create a file system you need a function which gives other functions based on the action needed
then we need to add that function into _G._Mount\[MountPath]
currently you need to supply functions for the following types
`open`,`attributes`,`list`,`copy`,`move`,`delete`,`makeDir`
provides the same functionality as the same function in normal fs

if you return `nil` for copy or move then it will create it's own using `open` and `delete`(move) or just `open`(copy)