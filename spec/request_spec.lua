describe('lift.request', function()

  local req = require 'lift.request'
  local stream = require 'lift.stream'
  local su = require 'spec.util'

  it("can fetch an HTML page", su.async(function()
    local sb = {} -- string buffer containing the page
    req('www.google.com/invalid_url'):pipe(stream.to_array(sb)):wait_finish()
    assert.match('404 Not Found', table.concat(sb))
  end))

  local function try_get(url)
    return function()
      local rs = req(url)
      repeat local data = rs:read() until data == nil
      assert(not rs.read_error)
    end
  end

  it("pushes errors onto the stream", su.async(function()
    assert.no_error(try_get('www.google.com/invalid_url'))
    assert.error_matches(try_get('-s www.google.com'), 'malformed URL')
    assert.error_matches(try_get('invalid.url'),
      'Could not resolve host: invalid.url')
    assert.error_matches(try_get('weird://protocol.com'),
      'Protocol "weird" not supported or disabled in libcurl')
  end))

  it("can fetch a PNG image (Google's logo)", su.async(function()
    local sb = {} -- string buffer containing the page
    req('www.google.com'):pipe(stream.to_array(sb)):wait_finish()
    local html = table.concat(sb)
    assert.equal('</html>', html:sub(-7))
    -- parse Google's logo URL
    local logo_path = html:match('background:url%(([^)]-googlelogo[^)]*)%)')
    -- download the PNG
    local sb2 = {}
    req('www.google.com'..logo_path):pipe(stream.to_array(sb2)):wait_finish()
    local content = table.concat(sb2)
    assert.equal(5482, #content) -- size of the PNG
  end))

end)