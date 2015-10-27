describe('Module lift.diagnostics', function()

  local diagnostics = require 'lift.diagnostics'

  describe('when creating diagnostic objects', function()

    it('formats messages by interpolating variables', function()
      local d = diagnostics.new('remark: lift is awesome!', 1*3, 2*3)
      assert.equal('remark', d.kind, d.level)
      assert.equal('lift is awesome!', d.message)
      assert.equal(3, d[1]) assert.equal(6, d[2])

      assert.error(function() diagnostics.new() end,
        "first arg must be a message")
      assert.error(function() diagnostics.new('no kind') end,
        "malformed diagnostic message 'no kind'")
      assert.error(function() diagnostics.new('crazy: kind') end,
        "unknown diagnostic kind 'crazy'")
    end)

    it('implements lazy formatting of messages', function()
      local three = diagnostics.new('remark: 3')
      local d = diagnostics.new('warning: ${1} + ${3} is not ${2}',
        1, '2', three)
      assert.equal('${1} + ${3} is not ${2}', d[0])
      assert.equal('1 + 3 is not 2', d.message)
      local remark = diagnostics.new('remark: Hey, ${1}!', d)
      assert.equal('Hey, 1 + 3 is not 2!', remark.message)
      assert.equal('warning', d.level)
      assert.equal('remark', three.level, remark.level)
    end)

    it('alternatively accepts a list in the constructor', function()
      local d = diagnostics.new({'remark: ${1}${2}${3} ${4}${5}',
        1, '2', 3}, 4, 5)
      assert.equal('123 ${4}${5}', d.message) -- varargs are lost
    end)

  end)

  it('supports diagnostic consumers', function()
    diagnostics.set_consumer(nil)
    assert.error(function() diagnostics.new('error: oops'):report() end,
      'undefined diagnostics consumer')
    assert.error(function() diagnostics.report('error: oops') end,
      'undefined diagnostics consumer')

    local last
    diagnostics.set_consumer(function(d) last = d end)
    local d = diagnostics.new('warning: this works')
    assert.equal(nil, last) d:report() assert.equal(d, last)
  end)

  it('provides tools for error handling', function()
    -- setting a new consumer resets the error count
    local verifier = diagnostics.Verifier.set_new()
    assert.no_error(function() diagnostics.fail_if_error() end)

    -- at any time we can raise a fatal diagnostic
    local fatal = diagnostics.new('fatal: killer')
    assert.error(function() fatal:report() end, fatal)
    assert.error(function() diagnostics.report('fatal: brace yourselves') end,
      {kind = 'fatal', level = 'fatal', [0] = 'brace yourselves'})

    local ok, err = pcall(diagnostics.report,
      'fatal: ${1} is coming', 'winter')
    assert.False(ok) assert.equal('winter is coming', tostring(err))

    -- fail_if_error() raises the latest error diagnostic, if any
    assert.no_error(function() diagnostics.fail_if_error() end)
    diagnostics.report('error: first')
    diagnostics.report('error: second')
    assert.error(function() diagnostics.fail_if_error() end,
      {kind = 'error', level = 'error', [0] = 'second'})

    -- our verifier should have accumulated only the two errors
    assert.equal(2, #verifier)
    assert.equal('first', verifier[1].message)
    assert.equal('second', verifier[2].message)

    -- verifier should receive all diagnostics except the 'ignored' ones
    diagnostics.report('ignored: not reported')
    assert.equal(2, #verifier)
    diagnostics.report('remark: reported')
    assert.equal(3, #verifier)
  end)

end)
