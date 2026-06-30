local helper = require('lua_helper')
helper.assertFileExists('build/configr_cross_platform_sweep.txt')
helper.assertFileContains('build/configr_cross_platform_sweep.txt', 'cross%-platform sweep')
