local modules={}
modules["lexer"]=function(require)
-- Byte-oriented Luau scanner. Patterns classify characters only; never rewrite source.
local Lexer = {}
local keywords = {}
for word in string.gmatch('and break do else elseif end false for function if in local nil not or repeat return then true until while', '%S+') do keywords[word] = true end
local operators = {'...', '..=', '//=', '+=', '-=', '*=', '/=', '%=', '^=', '==', '~=', '<=', '>=', '::', '->', '..', '//'}
local function utf8char(n)
    assert(n <= 1114111 and not (n >= 55296 and n <= 57343), 'invalid Unicode escape')
    if n < 128 then return string.char(n) end
    if n < 2048 then return string.char(192 + math.floor(n / 64), 128 + n % 64) end
    if n < 65536 then return string.char(224 + math.floor(n / 4096), 128 + math.floor(n / 64) % 64, 128 + n % 64) end
    return string.char(240 + math.floor(n / 262144), 128 + math.floor(n / 4096) % 64, 128 + math.floor(n / 64) % 64, 128 + n % 64)
end
function Lexer.lex(source)
    local tokens, pos, line, col = {}, 1, 1, 1
    local function peek(n) return source:sub(pos + (n or 0), pos + (n or 0)) end
    local function take()
        local c = peek(); pos = pos + 1
        if c == '\n' then line = line + 1; col = 1 else col = col + 1 end
        return c
    end
    local function fail(message) error('lexer ' .. line .. ':' .. col .. ': ' .. message, 0) end
    local function emit(kind, value, start, ln, cl)
        tokens[#tokens + 1] = {kind = kind, value = value, raw = source:sub(start, pos - 1), line = ln, col = cl}
    end
    local function longLevel()
        if peek() ~= '[' then return nil end
        local n = 1
        while peek(n) == '=' do n = n + 1 end
        if peek(n) == '[' then return n - 1 end
        return nil
    end
    local function longString(level)
        for _ = 1, level + 2 do take() end
        if peek() == '\r' then take(); if peek() == '\n' then take() end
        elseif peek() == '\n' then take(); if peek() == '\r' then take() end end
        local out, closing = {}, ']' .. string.rep('=', level) .. ']'
        while pos <= string.len(source) do
            if source:sub(pos, pos + string.len(closing) - 1) == closing then
                for _ = 1, string.len(closing) do take() end
                return table.concat(out)
            end
            local c = take()
            if c == '\r' or c == '\n' then
                local other = c == '\r' and '\n' or '\r'
                if peek() == other then take() end
                c = '\n'
            end
            out[#out + 1] = c
        end
        return fail('unfinished long string/comment')
    end
    local escapes = {a = '\a', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t', v = '\v', ['\\'] = '\\', ['"'] = '"', ["'"] = "'", ['`'] = '`', ['{'] = '{', ['}'] = '}'}
    local function escape()
        local c = take()
        if escapes[c] then return escapes[c] end
        if c == '\n' or c == '\r' then
            if (c == '\r' and peek() == '\n') or (c == '\n' and peek() == '\r') then take() end
            return '\n'
        end
        if c == 'z' then while peek() ~= '' and peek():match('%s') do take() end; return '' end
        if c == 'x' then
            local s = take() .. take()
            if not s:match('^%x%x$') then fail('invalid hex escape') end
            return string.char(tonumber(s, 16))
        end
        if c == 'u' then
            if take() ~= '{' then fail('expected { after \\u') end
            local s = ''
            while peek() ~= '' and peek():match('%x') do s = s .. take() end
            if take() ~= '}' or #s == 0 then fail('invalid Unicode escape') end
            return utf8char(tonumber(s, 16))
        end
        if c:match('%d') then
            local s = c
            for _ = 1, 2 do if peek() ~= '' and peek():match('%d') then s = s .. take() end end
            if tonumber(s) > 255 then fail('decimal escape exceeds 255') end
            return string.char(tonumber(s))
        end
        return fail('invalid escape')
    end
    local scan
    local function interpolation()
        local start, ln, cl = pos, line, col
        take(); emit('interp_start', '`', start, ln, cl)
        local segment = {}
        while pos <= string.len(source) do
            local c = peek()
            if c == '`' or c == '{' then
                emit('segment', table.concat(segment), pos, line, col); segment = {}
                if c == '`' then local p, l, k = pos, line, col; take(); emit('interp_end', '`', p, l, k); return end
                take(); scan(true)
            elseif c == '\\' then take(); segment[#segment + 1] = escape()
            else segment[#segment + 1] = take() end
        end
        fail('unfinished interpolation')
    end
    scan = function(inInterpolation)
        local braces = 0
        while pos <= string.len(source) do
            local c = peek()
            local start, ln, cl = pos, line, col
            if c:match('%s') then take()
            elseif c == '-' and peek(1) == '-' then
                take(); take(); local level = longLevel()
                if level then longString(level) else while peek() ~= '' and peek() ~= '\n' and peek() ~= '\r' do take() end end
            elseif c == '}' and inInterpolation and braces == 0 then
                take(); emit('interp_close', '}', start, ln, cl); return
            elseif c == '`' then interpolation()
            elseif c == '"' or c == "'" then
                take(); local out = {}
                while peek() ~= c do
                    if peek() == '' or peek() == '\n' or peek() == '\r' then fail('unfinished string') end
                    if peek() == '\\' then take(); out[#out + 1] = escape() else out[#out + 1] = take() end
                end
                take(); emit('string', table.concat(out), start, ln, cl)
            elseif c == '[' and longLevel() then emit('string', longString(longLevel()), start, ln, cl)
            elseif c:match('[%a_]') then
                take(); while peek() ~= '' and peek():match('[%w_]') do take() end
                local word = source:sub(start, pos - 1); emit(keywords[word] and word or 'name', word, start, ln, cl)
            elseif c:match('%d') or (c == '.' and peek(1):match('%d')) then
                local hex=c=='0' and (peek(1)=='x' or peek(1)=='X')
                local binary=c=='0' and (peek(1)=='b' or peek(1)=='B')
                if hex or binary then take(); take() end
                local digits=hex and '[%x_]' or binary and '[01_]' or '[%d_]'
                local count=0
                while peek()~='' and peek():match(digits) do if peek()~='_' then count=count+1 end; take() end
                if not binary and not hex and peek()=='.' and peek(1)~='.' then
                    take(); while peek()~='' and peek():match(digits) do if peek()~='_' then count=count+1 end; take() end
                end
                if count==0 then fail('number requires digits') end
                local exponent=hex and '[pP]' or '[eE]'
                if not binary and not hex and peek()~='' and peek():match(exponent) then
                    take(); if peek()=='+' or peek()=='-' then take() end
                    local expDigits=0
                    while peek()~='' and peek():match('[%d_]') do if peek()~='_' then expDigits=expDigits+1 end; take() end
                    if expDigits==0 then fail('exponent requires digits') end
                end
                if peek()~='' and peek():match('[%w_]') then fail('invalid numeric suffix') end
                emit('number', source:sub(start, pos - 1), start, ln, cl)
            else
                local op
                for _, candidate in ipairs(operators) do if source:sub(pos, pos + #candidate - 1) == candidate then op = candidate; break end end
                if op then for _ = 1, #op do take() end
                elseif c:find('[+%-%*/%%%^#=<>;:,%.%(%){%}%[%]|&?@]') then op = take()
                else fail('unexpected character ' .. c) end
                if op == '{' then braces = braces + 1 elseif op == '}' then braces = braces - 1 end
                emit(op, op, start, ln, cl)
            end
        end
        if inInterpolation then fail('unfinished interpolation expression') end
    end
    scan(false); emit('eof', '', pos, line, col)
    return tokens
end
return Lexer

end
modules["parser"]=function(require)
local Parser = {}
local precedence = {['or']=1, ['and']=2, ['<']=3, ['>']=3, ['<=']=3, ['>=']=3, ['~=']=3, ['==']=3, ['..']=4, ['+']=5, ['-']=5, ['*']=6, ['/']=6, ['//']=6, ['%']=6, ['^']=8}
local compound = {['+=']=true, ['-=']=true, ['*=']=true, ['/=']=true, ['//=']=true, ['%=']=true, ['^=']=true, ['..=']=true}
function Parser.parse(tokens)
    local p = 1
    local function tok(n) return tokens[p + (n or 0)] or tokens[#tokens] end
    local function is(k) return tok().kind == k end
    local function word(w) return tok().value == w end
    local function fail(message) error('parser ' .. tok().line .. ':' .. tok().col .. ': ' .. message .. ' (got ' .. tok().kind .. ')', 0) end
    local function take() local t = tok(); p = p + 1; return t end
    local function accept(k) if is(k) then return take() end; return nil end
    local function expect(k) if not is(k) then fail('expected ' .. k) end; return take() end
    local function name() return expect('name').value end
    local expr, block, func, typeExpr
    local function generic()
        local result = {}
        if accept('<') then
            repeat
                local item = {name = name(), pack = accept('...') ~= nil}
                if accept('=') then item.default = typeExpr() end
                result[#result + 1] = item
            until not accept(',')
            expect('>')
        end
        return result
    end
    local function typeAtom()
        local n
        if accept('...') then n = {tag='TypePack', value=typeExpr()}
        elseif is('<') then local g=generic(); local t=typeExpr(); n={tag='GenericType',generics=g,value=t}
        elseif accept('(') then
            local items = {}
            if not is(')') then repeat
                if is('name') and tok(1).kind == ':' then take(); take() end
                items[#items+1]=typeExpr()
            until not accept(',') end
            expect(')'); n={tag='TypeTuple',items=items}
        elseif accept('{') then
            local items={}
            while not is('}') do
                if is('eof') then fail('unfinished table type') end
                local item={}
                if is('name') and (word('read') or word('write')) and tok(1).kind ~= ':' and tok(1).kind ~= '}' then item.access=take().value end
                if accept('[') then item.key=typeExpr(); expect(']'); expect(':'); item.value=typeExpr()
                elseif is('name') and tok(1).kind==':' then item.name=name(); take(); item.value=typeExpr()
                else item.value=typeExpr() end
                items[#items+1]=item
                if not accept(',') and not accept(';') then break end
            end
            expect('}'); n={tag='TypeTable',items=items}
        elseif is('string') or is('true') or is('false') or is('nil') then n={tag='TypeLiteral',value=take().value}
        elseif is('name') then
            local id=name()
            if id=='typeof' and accept('(') then local e=expr(); expect(')'); n={tag='Typeof',value=e}
            else
                local path={id}; while accept('.') do path[#path+1]=name() end
                local args={}
                if accept('<') then
                    if not is('>') then repeat args[#args+1]=typeExpr() until not accept(',') end
                    expect('>')
                end
                n={tag='TypeName',path=path,args=args,pack=accept('...')~=nil}
            end
        else fail('expected type') end
        while accept('?') do n={tag='OptionalType',value=n} end
        if accept('->') then n={tag='FunctionType',params=n,result=typeExpr()} end
        return n
    end
    typeExpr = function()
        local leading=accept('|') or accept('&')
        local n=typeAtom()
        while is('|') or is('&') do local op=take().kind; n={tag='TypeBinary',op=op,left=n,right=typeAtom()} end
        if leading then n.leading=leading.kind end
        return n
    end
    local function binding()
        local b={tag='Binding',name=name()}
        if accept(':') then b.annotation=typeExpr() end
        return b
    end
    local function exprlist()
        local list={expr()}; while accept(',') do list[#list+1]=expr() end; return list
    end
    local function attributes()
        local list={}
        local function item(parameters)
            local a={name=name()}
            if parameters then
                if accept('(') then
                    a.args={}; if not is(')') then a.args=exprlist() end; expect(')')
                elseif is('string') or is('{') then a.args={expr()} end
            end
            return a
        end
        while accept('@') do
            if accept('[') then repeat list[#list+1]=item(true) until not accept(','); expect(']')
            else list[#list+1]=item(false) end
        end
        return list
    end
    func = function(method, attrs)
        local generics=generic(); expect('(')
        local params={}; local vararg=false; local varargType
        if not is(')') then repeat
            if accept('...') then vararg=true; if accept(':') then varargType=typeExpr() end; break end
            params[#params+1]=binding()
        until not accept(',') end
        expect(')'); local result
        if accept(':') then result=typeExpr() end
        local body=block(); expect('end')
        return {tag='Function',params=params,vararg=vararg,varargType=varargType,result=result,generics=generics,body=body,method=method,attributes=attrs or {}}
    end
    local function tableExpr()
        expect('{'); local fields={}
        while not is('}') do
            local f={}
            if accept('[') then f.key=expr(); expect(']'); expect('='); f.value=expr()
            elseif is('name') and tok(1).kind=='=' then f.name=name(); take(); f.value=expr()
            else f.value=expr() end
            fields[#fields+1]=f
            if not accept(',') and not accept(';') then break end
        end
        expect('}'); return {tag='Table',fields=fields}
    end
    local function args()
        if accept('(') then local a={}; if not is(')') then a=exprlist() end; expect(')'); return a
        elseif is('{') then return {tableExpr()}
        elseif is('string') then return {{tag='String',value=take().value}} end
        return fail('expected call arguments')
    end
    local function primary()
        local n
        if is('number') then n={tag='Number',raw=take().value}
        elseif is('string') then n={tag='String',value=take().value}
        elseif is('nil') or is('true') or is('false') then n={tag='Literal',value=take().kind}
        elseif accept('...') then n={tag='Vararg'}
        elseif accept('function') then n=func(false)
        elseif is('@') then local a=attributes(); expect('function'); n=func(false,a)
        elseif is('{') then n=tableExpr()
        elseif accept('if') then
            local branches={}
            repeat local c=expr(); expect('then'); branches[#branches+1]={condition=c,value=expr()} until not accept('elseif')
            expect('else'); n={tag='IfExpr',branches=branches,otherwise=expr()}
        elseif accept('interp_start') then
            local parts={}
            repeat
                parts[#parts+1]={tag='String',value=expect('segment').value}
                if is('interp_end') then break end
                parts[#parts+1]=expr(); expect('interp_close')
            until false
            expect('interp_end'); n={tag='Interpolation',parts=parts}
        elseif accept('(') then n={tag='Paren',value=expr()}; expect(')')
        elseif is('name') then n={tag='Name',name=name()}
        else fail('expected expression') end
        while true do
            if accept('.') then n={tag='Field',base=n,name=name()}
            elseif accept('[') then local key=expr(); expect(']'); n={tag='Index',base=n,key=key}
            elseif is(':') then take(); local m=name(); n={tag='Call',callee=n,method=m,args=args()}
            elseif is('(') or is('{') or is('string') then n={tag='Call',callee=n,args=args()}
            elseif accept('::') then n={tag='Cast',value=n,annotation=typeExpr()}
            else break end
        end
        return n
    end
    expr = function(minimum)
        minimum=minimum or 0
        local n
        if is('not') or is('-') or is('#') then local op=take().kind; n={tag='Unary',op=op,value=expr(7)} else n=primary() end
        while precedence[tok().kind] and precedence[tok().kind] > minimum do
            local op=take().kind; local level=precedence[op]
            n={tag='Binary',op=op,left=n,right=expr((op=='^' or op=='..') and level-1 or level)}
        end
        return n
    end
    local endings={['end']=true,['else']=true,['elseif']=true,['until']=true,['eof']=true}
    local function statement()
        local attrs=attributes()
        if accept('local') or (word('const') and (tok(1).kind=='name' or tok(1).kind=='function') and take()) then
            local constant=tokens[p-1].value=='const'
            if accept('function') then local b=binding(); return {tag='LocalFunction',binding=b,value=func(false,attrs),constant=constant} end
            local bindings={binding()}; while accept(',') do bindings[#bindings+1]=binding() end
            local values={}; if accept('=') then values=exprlist() end
            return {tag='Local',bindings=bindings,values=values,constant=constant}
        elseif accept('function') then
            local target={tag='Name',name=name()}
            while accept('.') do target={tag='Field',base=target,name=name()} end
            local method
            if accept(':') then method=name() end
            return {tag='FunctionDecl',target=target,method=method,value=func(method~=nil,attrs)}
        elseif #attrs>0 then return fail('attributes require function')
        elseif accept('do') then local b=block(); expect('end'); return {tag='Do',body=b}
        elseif accept('while') then local c=expr(); expect('do'); local b=block(); expect('end'); return {tag='While',condition=c,body=b}
        elseif accept('repeat') then local b=block(); expect('until'); return {tag='Repeat',body=b,condition=expr()}
        elseif accept('if') then
            local branches={}
            repeat local c=expr(); expect('then'); branches[#branches+1]={condition=c,body=block()} until not accept('elseif')
            local other; if accept('else') then other=block() end
            expect('end'); return {tag='If',branches=branches,otherwise=other}
        elseif accept('for') then
            local bindings={binding()}
            if accept('=') then
                local first=expr(); expect(','); local last=expr(); local step
                if accept(',') then step=expr() end
                expect('do'); local b=block(); expect('end')
                return {tag='NumericFor',binding=bindings[1],first=first,last=last,step=step,body=b}
            end
            while accept(',') do bindings[#bindings+1]=binding() end
            expect('in'); local values=exprlist(); expect('do'); local b=block(); expect('end')
            return {tag='GenericFor',bindings=bindings,values=values,body=b}
        elseif accept('return') then
            local values={}; if not endings[tok().kind] and not is(';') then values=exprlist() end
            return {tag='Return',values=values}
        elseif accept('break') then return {tag='Break'}
        elseif word('continue') and (endings[tok(1).kind] or tok(1).kind==';') then take(); return {tag='Continue'}
        elseif (word('type') and (tok(1).kind=='name' or tok(1).kind=='function')) or (word('export') and tok(1).value=='type') then
            local exported=false; if word('export') then take(); exported=true end
            take()
            if accept('function') then local id=name(); return {tag='TypeDeclaration',name=id,value=func(false),exported=exported} end
            local id=name(); local g=generic(); expect('=')
            return {tag='TypeDeclaration',name=id,generics=g,value=typeExpr(),exported=exported}
        else
            local first=expr()
            if first.tag=='Call' and not is(',') and not is('=') and not compound[tok().kind] then return {tag='CallStatement',value=first} end
            local targets={first}; while accept(',') do targets[#targets+1]=expr() end
            for _, v in ipairs(targets) do if v.tag~='Name' and v.tag~='Field' and v.tag~='Index' then fail('invalid assignment target') end end
            if compound[tok().kind] then
                if #targets~=1 then fail('compound assignment requires one target') end
                local op=take().kind; return {tag='Compound',target=first,op=op,value=expr()}
            end
            expect('='); return {tag='Assign',targets=targets,values=exprlist()}
        end
    end
    block = function()
        local b={tag='Block',body={}}
        while not endings[tok().kind] do
            if accept(';') then else
                local s=statement(); b.body[#b.body+1]=s; accept(';')
                if s.tag=='Return' or s.tag=='Break' or s.tag=='Continue' then
                    if not endings[tok().kind] then fail('statement after terminator') end
                end
            end
        end
        return b
    end
    local tree=block(); expect('eof'); return tree
end
return Parser

end
modules["codegen"]=function(require)
local G = {}
function G.quote(value)
    local out={'"'}
    for i=1,string.len(value) do
        local b=value:byte(i)
        if b>=32 and b<=126 and b~=34 and b~=92 then out[#out+1]=string.char(b)
        else out[#out+1]=string.format('\\%03d',b) end
    end
    out[#out+1]='"'; return table.concat(out)
end
function G.generate(tree)
    local expression, statement, block
    local function list(items, fn)
        local out={}; for i,v in ipairs(items) do out[i]=fn(v) end; return table.concat(out,',')
    end
    local function binding(b) return b.name end
    local function attr(f)
        if not f.attributes or #f.attributes==0 then return '' end
        local items={}
        for i,a in ipairs(f.attributes) do
            items[i]=a.name .. (a.args and '(' .. list(a.args,expression) .. ')' or '')
        end
        return '@[' .. table.concat(items,',') .. '] '
    end
    local function functionBody(f)
        local params=list(f.params,binding)
        if f.vararg then params=params .. (#f.params>0 and ',...' or '...') end
        return '(' .. params .. ')\n' .. block(f.body) .. '\nend'
    end
    expression=function(n)
        local t=n.tag
        if t=='Name' then return n.name
        elseif t=='Number' then return n.raw
        elseif t=='String' then return G.quote(n.value)
        elseif t=='Literal' then return n.value
        elseif t=='Vararg' then return '...'
        elseif t=='Paren' or t=='Cast' then return '(' .. expression(n.value) .. ')'
        elseif t=='Unary' then return '(' .. n.op .. ' ' .. expression(n.value) .. ')'
        elseif t=='Binary' then return '(' .. expression(n.left) .. ' ' .. n.op .. ' ' .. expression(n.right) .. ')'
        elseif t=='Field' then return '(' .. expression(n.base) .. ').' .. n.name
        elseif t=='Index' then return '(' .. expression(n.base) .. ')[' .. expression(n.key) .. ']'
        elseif t=='Call' then return '(' .. expression(n.callee) .. ')' .. (n.method and ':' .. n.method or '') .. '(' .. list(n.args,expression) .. ')'
        elseif t=='Function' then return attr(n) .. 'function' .. functionBody(n)
        elseif t=='Table' then
            return '{' .. list(n.fields,function(f)
                if f.name then return f.name .. '=' .. expression(f.value) end
                if f.key then return '[' .. expression(f.key) .. ']=' .. expression(f.value) end
                return expression(f.value)
            end) .. '}'
        elseif t=='IfExpr' then
            local out={}; for i,b in ipairs(n.branches) do out[#out+1]=(i==1 and 'if ' or 'elseif ') .. expression(b.condition) .. ' then ' .. expression(b.value) .. ' ' end
            return '(' .. table.concat(out) .. 'else ' .. expression(n.otherwise) .. ')'
        elseif t=='Interpolation' then
            local out={'`'}
            for i,v in ipairs(n.parts) do
                if i%2==1 then
                    for j=1,#v.value do
                        local b=v.value:byte(j)
                        if b>=32 and b<=126 and b~=96 and b~=123 and b~=125 and b~=92 then out[#out+1]=string.char(b)
                        else out[#out+1]=string.format('\\%03d',b) end
                    end
                else out[#out+1]='{ ' .. expression(v) .. ' }' end
            end
            out[#out+1]='`'; return table.concat(out)
        end
        error('codegen: unknown expression ' .. tostring(t))
    end
    statement=function(n)
        local t=n.tag
        if t=='Local' then return (n.constant and 'const ' or 'local ') .. list(n.bindings,binding) .. (#n.values>0 and '=' .. list(n.values,expression) or '')
        elseif t=='LocalFunction' then return attr(n.value) .. (n.constant and 'const function ' or 'local function ') .. n.binding.name .. functionBody(n.value)
        elseif t=='FunctionDecl' then
            -- Keep method syntax: the implicit self parameter and call semantics matter.
            local function path(v)
                if v.tag=='Name' then return v.name end
                assert(v.tag=='Field'); return path(v.base) .. '.' .. v.name
            end
            return attr(n.value) .. 'function ' .. path(n.target) .. (n.method and ':' .. n.method or '') .. functionBody(n.value)
        elseif t=='Assign' then return list(n.targets,expression) .. '=' .. list(n.values,expression)
        elseif t=='Compound' then return expression(n.target) .. n.op .. expression(n.value)
        elseif t=='CallStatement' then return expression(n.value)
        elseif t=='Return' then return 'return ' .. list(n.values,expression)
        elseif t=='Break' then return 'break'
        elseif t=='Continue' then return 'continue'
        elseif t=='Do' then return 'do\n' .. block(n.body) .. '\nend'
        elseif t=='While' then return 'while ' .. expression(n.condition) .. ' do\n' .. block(n.body) .. '\nend'
        elseif t=='Repeat' then return 'repeat\n' .. block(n.body) .. '\nuntil ' .. expression(n.condition)
        elseif t=='NumericFor' then return 'for ' .. n.binding.name .. '=' .. expression(n.first) .. ',' .. expression(n.last) .. (n.step and ',' .. expression(n.step) or '') .. ' do\n' .. block(n.body) .. '\nend'
        elseif t=='GenericFor' then return 'for ' .. list(n.bindings,binding) .. ' in ' .. list(n.values,expression) .. ' do\n' .. block(n.body) .. '\nend'
        elseif t=='If' then
            local out={}
            for i,b in ipairs(n.branches) do out[#out+1]=(i==1 and 'if ' or 'elseif ') .. expression(b.condition) .. ' then\n' .. block(b.body) end
            if n.otherwise then out[#out+1]='else\n' .. block(n.otherwise) end
            return table.concat(out,'\n') .. '\nend'
        elseif t=='TypeDeclaration' then return '' end
        error('codegen: unknown statement ' .. tostring(t))
    end
    block=function(b)
        local out={}; for _,s in ipairs(b.body) do local code=statement(s); if code~='' then out[#out+1]=code .. ';' end end
        return table.concat(out,'\n')
    end
    return block(tree)
end
return G

end
modules["ast"]=function(require)
local A = {}
local skip={annotation=true,generics=true,varargType=true,result=true,attributes=true}
-- Postorder; replacements are not revisited in this pass.
function A.map(node, visitor)
    if type(node)~='table' then return node end
    if node.tag=='TypeDeclaration' then return node end
    for key,value in pairs(node) do
        if not skip[key] and type(value)=='table' then node[key]=A.map(value,visitor) end
    end
    if node.tag then return visitor(node) or node end
    return node
end
function A.name(s) return {tag='Name',name=s} end
function A.number(n) return {tag='Number',raw=tostring(n)} end
function A.literal(v) return {tag='Literal',value=v} end
function A.binary(op,l,r) return {tag='Binary',op=op,left=l,right=r} end
function A.block(body) return {tag='Block',body=body or {}} end
function A.call(name,args) return {tag='Call',callee=A.name(name),args=args} end
function A.assign(name,value) return {tag='Assign',targets={A.name(name)},values={value}} end
function A.localvar(name,value) return {tag='Local',bindings={{tag='Binding',name=name}},values={value}} end
function A.context(tree,config)
    local used={}
    A.map(tree,function(n) if n.name then used[n.name]=true end end)
    local ctx={config=config,used=used,counter=0,helpers={},warnings={},stats={}}
    function ctx:fresh()
        repeat self.counter=self.counter+1 until not self.used['__O' .. self.counter .. 'lI']
        local s='__O' .. self.counter .. 'lI'; self.used[s]=true; return s
    end
    function ctx:count(key) self.stats[key]=(self.stats[key] or 0)+1 end
    return ctx
end
return A

end
modules["config"]=function(require)
return {
    rename=true,
    string_encrypt=true,
    number_encrypt=false,
    control_flow='off',
    dead_code=false,
    wrapper=false,
    wrapper_functions={},
    vm=false,
    compat_mode=true,
    seed=137,
}

end
modules["compat"]=function(require)
local Lexer=require('./lexer')
local Parser=require('./parser')
local M={}
function M.inject(ctx)
    local name=ctx:fresh()
    local source='local ' .. name .. [[=(function()
        local c={}
        c.unpack=table.unpack or unpack
        if type(c.unpack)~="function" then
            c.unpack=function(t,i,j)
                i=i or 1 j=j or #t
                if i<=j then return t[i],c.unpack(t,i+1,j) end
            end
        end
        c.pack=function(...) return {n=select("#",...),...} end
        c.environment=function(fallback)
            if type(getfenv)=="function" and type(pcall)=="function" then
                local ok,env=pcall(getfenv,0)
                if ok and type(env)=="table" then return env end
            end
            return fallback or _G or {}
        end
        c.load=function(source,environment)
            if type(loadstring)~="function" or type(pcall)~="function" then return nil,"dynamic compilation unavailable" end
            local loaded,fn,err=pcall(loadstring,source)
            if not loaded then return nil,"dynamic compilation blocked" end
            if not fn then return nil,err end
            if environment then
                if type(setfenv)~="function" or type(pcall)~="function" then return nil,"environment binding unavailable" end
                local ok=pcall(setfenv,fn,environment)
                if not ok then return nil,"environment binding blocked" end
            end
            return fn
        end
        c.proxy=function()
            if type(newproxy)=="function" and type(pcall)=="function" then
                local ok,value=pcall(newproxy,true)
                if ok then return value end
            end
            if type(setmetatable)=="function" then return setmetatable({},{}) end
            return {}
        end
        return c
    end)()]]
    return Parser.parse(Lexer.lex(source)).body[1]
end
return M

end
modules["passes/rename"]=function(require)
local M={}
function M.run(tree,ctx)
    local scopes={{}}
    local expr, block, statement
    local function push() scopes[#scopes+1]={} end
    local function pop() scopes[#scopes]=nil end
    local function bind(b,pinned)
        local old=b.name; local new=pinned and old or ctx:fresh()
        scopes[#scopes][old]=new; b.name=new; ctx:count('renamed')
    end
    local function reference(n)
        for i=#scopes,1,-1 do if scopes[i][n.name] then n.name=scopes[i][n.name]; return end end
    end
    local function expressions(items) for _,n in ipairs(items) do expr(n) end end
    expr=function(n)
        if not n then return end
        local t=n.tag
        if t=='Name' then reference(n)
        elseif t=='Function' then
            push()
            if n.method then scopes[#scopes].self='self' end
            for _,b in ipairs(n.params) do bind(b) end
            block(n.body,false); pop()
        elseif t=='Binary' then expr(n.left); expr(n.right)
        elseif t=='Unary' or t=='Paren' or t=='Cast' then expr(n.value)
        elseif t=='Field' then expr(n.base)
        elseif t=='Index' then expr(n.base); expr(n.key)
        elseif t=='Call' then expr(n.callee); expressions(n.args)
        elseif t=='Table' then for _,f in ipairs(n.fields) do expr(f.key); expr(f.value) end
        elseif t=='Interpolation' then expressions(n.parts)
        elseif t=='IfExpr' then for _,b in ipairs(n.branches) do expr(b.condition); expr(b.value) end; expr(n.otherwise) end
    end
    statement=function(n)
        local t=n.tag
        if t=='Local' then expressions(n.values); for _,b in ipairs(n.bindings) do bind(b) end
        elseif t=='LocalFunction' then bind(n.binding); expr(n.value)
        elseif t=='FunctionDecl' then expr(n.target); expr(n.value)
        elseif t=='Assign' then expressions(n.targets); expressions(n.values)
        elseif t=='Compound' then expr(n.target); expr(n.value)
        elseif t=='CallStatement' then expr(n.value)
        elseif t=='Return' then expressions(n.values)
        elseif t=='Do' then block(n.body,true)
        elseif t=='While' then expr(n.condition); block(n.body,true)
        elseif t=='Repeat' then push(); block(n.body,false); expr(n.condition); pop()
        elseif t=='If' then for _,b in ipairs(n.branches) do expr(b.condition); block(b.body,true) end; if n.otherwise then block(n.otherwise,true) end
        elseif t=='NumericFor' then expr(n.first); expr(n.last); expr(n.step); push(); bind(n.binding); block(n.body,false); pop()
        elseif t=='GenericFor' then expressions(n.values); push(); for _,b in ipairs(n.bindings) do bind(b) end; block(n.body,false); pop() end
    end
    block=function(b,scoped)
        if scoped then push() end
        for _,s in ipairs(b.body) do statement(s) end
        if scoped then pop() end
    end
    block(tree,false); return tree
end
return M

end
modules["passes/string_encrypt"]=function(require)
local A=require('../ast')
local Lexer=require('../lexer')
local Parser=require('../parser')
local M={}
local function xor(a,b)
    local result,bit=0,1
    for _=1,8 do local x,y=a%2,b%2; if x~=y then result=result+bit end; a=math.floor(a/2); b=math.floor(b/2); bit=bit*2 end
    return result
end
function M.run(tree,ctx)
    local stringsName=ctx:fresh(); local count=0
    local poolName,cacheName=ctx:fresh(),ctx:fresh()
    local pool={tag='Table',fields={}}
    local function encrypt(value)
        count=count+1
        local key=(ctx.config.seed+count*31)%251+1
        local fields={}; local checksum=0
        for i=1,string.len(value) do
            local byte=value:byte(i)
            checksum=(checksum+byte*i)%65521
            fields[i]={value=A.number((xor(byte,key)+i*17)%256)}
        end
        ctx:count('strings')
        pool.fields[count]={value={tag='Table',fields={{value={tag='Table',fields=fields}},{value=A.number(key)},{value=A.number(checksum)}}}}
        return {tag='Index',base=A.name(stringsName),key=A.number(count)}
    end
    -- Interpolation literal slots must remain strings. Move encrypted segments into
    -- expression slots without changing the order of the original expressions.
    local function visit(n)
        if type(n)~='table' or n.tag=='TypeDeclaration' then return n end
        if n.tag=='String' then return encrypt(n.value) end
        if n.tag=='Interpolation' then
            local parts={{tag='String',value=''}}
            for i,v in ipairs(n.parts) do
                parts[#parts+1]=i%2==1 and encrypt(v.value) or visit(v)
                parts[#parts+1]={tag='String',value=''}
            end
            n.parts=parts; return n
        end
        for k,v in pairs(n) do
            if k~='annotation' and k~='generics' and k~='result' and k~='varargType' and k~='attributes' and type(v)=='table' then n[k]=visit(v) end
        end
        return n
    end
    visit(tree)
    if count>0 then
        -- Only the string table remains live in the user's outer scope. A table
        -- hit avoids a Lua function call for every literal in a hot loop.
        local setup={A.localvar(poolName,pool),A.localvar(cacheName,A.name(stringsName))}
        local decrypt=ctx:fresh()
        local floorName,charName,concatName,errorName=ctx:fresh(),ctx:fresh(),ctx:fresh(),ctx:fresh()
        local captures=Parser.parse(Lexer.lex('local '..floorName..','..charName..','..concatName..','..errorName..'=math.floor,string.char,table.concat,error'))
        for _,s in ipairs(captures.body) do setup[#setup+1]=s end
        -- Parse helper source too: all injected output is represented in the AST.
        local source='local function ' .. decrypt .. '(id)\n' ..
            'local entry='..poolName..'[id]\nlocal data,key,expected=entry[1],entry[2],entry[3]\n' .. [[
            local out={}
            local sum=0
            for i=1,#data do
                local a=(data[i]-i*17)%256
                local b=key
                local value=0
                local bit=1
                for j=1,8 do
                    if a%2~=b%2 then value=value+bit end
                    a=math.floor(a/2) b=math.floor(b/2) bit=bit*2
                end
                sum=(sum+value*i)%65521
                out[i]=string.char(value)
            end
            if sum~=expected then error("string integrity check failed",0) end
            local result=table.concat(out)
        ]] .. cacheName .. '[id]=result\nreturn result\nend'
        local helper=Parser.parse(Lexer.lex(source)).body[1]
        A.map(helper,function(n)
            if n.tag=='Field' and n.base.tag=='Name' then
                if n.base.name=='math' and n.name=='floor' then return A.name(floorName) end
                if n.base.name=='string' and n.name=='char' then return A.name(charName) end
                if n.base.name=='table' and n.name=='concat' then return A.name(concatName) end
            elseif n.tag=='Name' and n.name=='error' then return A.name(errorName) end
            return nil
        end)
        setup[#setup+1]=helper
        -- Decode on the first miss; without metatables, decode eagerly once.
        local initialize='if type(setmetatable)=="function" then setmetatable('..cacheName..
            ',{__index=function(_,id) return '..decrypt..'(id) end}) else for id=1,#'..poolName..
            ' do '..decrypt..'(id) end end'
        local initialization=Parser.parse(Lexer.lex(initialize))
        for _,s in ipairs(initialization.body) do setup[#setup+1]=s end
        ctx.helpers[#ctx.helpers+1]=A.localvar(stringsName,{tag='Table',fields={}})
        ctx.helpers[#ctx.helpers+1]={tag='Do',body=A.block(setup)}
    end
    return tree
end
return M

end
modules["passes/number_encrypt"]=function(require)
local A=require('../ast')
local M={}
function M.run(tree,ctx)
    return A.map(tree,function(n)
        if n.tag~='Number' then return end
        -- Restrict to exact, small decimal integers; floats, infinity, hex and -0 stay intact.
        if not n.raw:match('^%d+$') then return end
        local value=tonumber(n.raw)
        if not value or value>1073741824 then return end
        local key=17+(ctx.counter%97)
        ctx:count('numbers')
        return A.binary('-',A.number(value+key),A.number(key))
    end)
end
return M

end
modules["passes/control_flow_flatten"]=function(require)
local A=require('../ast')
local M={}
local function hasTransfer(n)
    if type(n)~='table' then return false end
    if n.tag=='Function' then return false end
    if n.tag=='Break' or n.tag=='Continue' then return true end
    for _,v in pairs(n) do if type(v)=='table' and hasTransfer(v) then return true end end
    return false
end
function M.run(tree,ctx)
    local level=ctx.config.control_flow
    local budget=ctx.config.control_flow_budget or ({light=8,medium=32,heavy=128})[level]
    return A.map(tree,function(n)
        if budget<=0 then return end
        if n.tag=='While' and level~='light' then
            budget=budget-1; local state=ctx:fresh()
            local body={A.assign(state,A.number(1))}
            for _,s in ipairs(n.body.body) do body[#body+1]=s end
            local dispatch={tag='If',branches={
                {condition=A.binary('==',A.name(state),A.number(1)),body=A.block({
                    A.assign(state,A.number(2)),
                    {tag='If',branches={{condition={tag='Unary',op='not',value=n.condition},body=A.block({{tag='Break'}})}}}
                })},
                {condition=A.binary('==',A.name(state),A.number(2)),body=A.block(body)}
            }}
            ctx:count('flattened_while')
            return {tag='Do',body=A.block({A.localvar(state,A.number(1)),{tag='While',condition=A.literal('true'),body=A.block({dispatch})}})}
        elseif n.tag=='If' and not hasTransfer(n) then
            budget=budget-1; local state=ctx:fresh(); local choices={}
            local dispatch={tag='If',branches={}}
            for i,b in ipairs(n.branches) do
                choices[#choices+1]={condition=b.condition,body=A.block({A.assign(state,A.number(i))})}
                local body={A.assign(state,A.number(0))}; for _,s in ipairs(b.body.body) do body[#body+1]=s end
                dispatch.branches[#dispatch.branches+1]={condition=A.binary('==',A.name(state),A.number(i)),body=A.block(body)}
            end
            local other
            if n.otherwise then
                local id=#choices+1; other=A.block({A.assign(state,A.number(id))})
                local body={A.assign(state,A.number(0))}; for _,s in ipairs(n.otherwise.body) do body[#body+1]=s end
                dispatch.branches[#dispatch.branches+1]={condition=A.binary('==',A.name(state),A.number(id)),body=A.block(body)}
            end
            ctx:count('flattened_if')
            return {tag='Do',body=A.block({A.localvar(state,A.number(0)),{tag='If',branches=choices,otherwise=other},{tag='While',condition=A.binary('~=',A.name(state),A.number(0)),body=A.block({dispatch})}})}
        elseif (n.tag=='NumericFor' or n.tag=='GenericFor') and level=='heavy' and not hasTransfer(n.body) then
            budget=budget-1; local state=ctx:fresh()
            local body={A.assign(state,A.number(0))}; for _,s in ipairs(n.body.body) do body[#body+1]=s end
            local dispatch={tag='If',branches={{condition=A.binary('==',A.name(state),A.number(1)),body=A.block(body)}}}
            local loop={tag='While',condition=A.binary('~=',A.name(state),A.number(0)),body=A.block({dispatch})}
            n.body=A.block({A.localvar(state,A.number(1)),loop})
            ctx:count('flattened_for')
        end
        return nil
    end)
end
return M

end
modules["passes/dead_code"]=function(require)
local A=require('../ast')
local M={}
function M.run(tree,ctx)
    local budget=ctx.config.dead_code_budget or 16
    return A.map(tree,function(n)
        if n.tag=='Block' and budget>0 then
            budget=budget-1
            table.insert(n.body,1,{tag='If',branches={{condition=A.binary('==',A.number(19),A.number(23)),body=A.block({A.localvar(ctx:fresh(),A.number(0))})}}})
            ctx:count('dead_branches')
        end
    end)
end
return M

end
modules["passes/wrapper"]=function(require)
local A=require('../ast')
local Lexer=require('../lexer')
local Parser=require('../parser')
local M={}
function M.run(tree,ctx)
    -- Opt-in global calls only. No method lowering, stack-sensitive API or local alias guessing.
    local selected={}
    for _,name in ipairs(ctx.config.wrapper_functions or {}) do selected[name]=true end
    local forbidden={getfenv=true,setfenv=true,error=true,pcall=true,xpcall=true,require=true}
    for name in pairs(selected) do assert(not forbidden[name],'wrapper: stack-sensitive function ' .. name) end
    local proxy=ctx:fresh(); local count=0
    A.map(tree,function(n)
        if n.tag=='Call' and not n.method and n.callee.tag=='Name' and selected[n.callee.name] then
            local args={n.callee}; for _,v in ipairs(n.args) do args[#args+1]=v end
            count=count+1; ctx:count('wrapped_calls'); return A.call(proxy,args)
        end
        return nil
    end)
    if count>0 then ctx.helpers[#ctx.helpers+1]=Parser.parse(Lexer.lex('local function ' .. proxy .. '(f,...) return f(...) end')).body[1] end
    return tree
end
return M

end
modules["vm/compiler"]=function(require)
-- Optional closed-program register VM. Unsupported constructs fail at build time.
local A=require('../ast')
local C={}
function C.compile(tree)
    local code,scopes,loops={},{{}},{}
    local registers=0
    local expression,statement,block
    local function fresh() registers=registers+1; return registers end
    local function emit(op,a,b,c,d) code[#code+1]={op,a,b,c,d}; return #code end
    local function lookup(name)
        for i=#scopes,1,-1 do if scopes[i][name] then return scopes[i][name] end end
        error('vm: global access is outside the closed-program subset: ' .. name,0)
    end
    local function unsupported(n) error('vm: unsupported AST node ' .. n.tag .. '; use vm=false for native Luau',0) end
    expression=function(n)
        local r=fresh(); local t=n.tag
        if t=='Number' then
            -- Use the original literal as an AST constant, preserving Luau numeric parsing.
            emit(1,r,n)
        elseif t=='String' or t=='Literal' then emit(1,r,n)
        elseif t=='Name' then emit(2,r,lookup(n.name))
        elseif t=='Paren' or t=='Cast' then return expression(n.value)
        elseif t=='Unary' then emit(4,r,n.op,expression(n.value))
        elseif t=='Binary' then
            local left=expression(n.left)
            if n.op=='and' or n.op=='or' then
                emit(2,r,left)
                local jump=emit(n.op=='and' and 6 or 7,left,0)
                emit(2,r,expression(n.right)); code[jump][3]=#code+1
            else emit(3,r,n.op,left,expression(n.right)) end
        elseif t=='IfExpr' then
            local exits={}
            for _,b in ipairs(n.branches) do
                local jump=emit(6,expression(b.condition),0)
                emit(2,r,expression(b.value)); exits[#exits+1]=emit(5,0); code[jump][3]=#code+1
            end
            emit(2,r,expression(n.otherwise)); for _,j in ipairs(exits) do code[j][2]=#code+1 end
        else unsupported(n) end
        return r
    end
    local function values(items) local out={}; for i,n in ipairs(items) do out[i]=expression(n) end; return out end
    local function nilreg() local r=fresh(); emit(1,r,A.literal('nil')); return r end
    statement=function(n)
        local t=n.tag
        if t=='TypeDeclaration' then return
        elseif t=='Local' then
            local rhs=values(n.values)
            for i,b in ipairs(n.bindings) do local r=fresh(); emit(2,r,rhs[i] or nilreg()); scopes[#scopes][b.name]=r end
        elseif t=='Assign' then
            local rhs=values(n.values)
            for i,target in ipairs(n.targets) do if target.tag~='Name' then unsupported(target) end; emit(2,lookup(target.name),rhs[i] or nilreg()) end
        elseif t=='Compound' then
            if n.target.tag~='Name' then unsupported(n.target) end
            local dest=lookup(n.target.name); local old=fresh(); emit(2,old,dest)
            emit(3,dest,n.op:sub(1,-2),old,expression(n.value))
        elseif t=='Return' then emit(8,values(n.values))
        elseif t=='Do' then block(n.body,true)
        elseif t=='If' then
            local exits={}
            for _,b in ipairs(n.branches) do
                local jump=emit(6,expression(b.condition),0); block(b.body,true)
                exits[#exits+1]=emit(5,0); code[jump][3]=#code+1
            end
            if n.otherwise then block(n.otherwise,true) end
            for _,j in ipairs(exits) do code[j][2]=#code+1 end
        elseif t=='While' or t=='Repeat' then
            local start=#code+1; local loop={breaks={},continues={}}; loops[#loops+1]=loop
            local exit
            if t=='While' then exit=emit(6,expression(n.condition),0); block(n.body,true)
            else scopes[#scopes+1]={}; block(n.body,false) end
            local continueTarget=t=='While' and start or #code+1
            if t=='Repeat' then emit(6,expression(n.condition),start); scopes[#scopes]=nil else emit(5,start) end
            local finish=#code+1
            if exit then code[exit][3]=finish end
            for _,j in ipairs(loop.breaks) do code[j][2]=finish end
            for _,j in ipairs(loop.continues) do code[j][2]=continueTarget end
            loops[#loops]=nil
        elseif t=='Break' or t=='Continue' then
            assert(#loops>0,'vm: loop transfer outside a loop')
            local list=t=='Break' and loops[#loops].breaks or loops[#loops].continues
            list[#list+1]=emit(5,0)
        else unsupported(n) end
    end
    block=function(b,scoped)
        if scoped then scopes[#scopes+1]={} end
        for _,n in ipairs(b.body) do statement(n) end
        if scoped then scopes[#scopes]=nil end
    end
    block(tree,false); emit(8,{})
    local function serialize(v)
        if type(v)=='table' and v.tag then return v end
        if type(v)=='number' then return A.number(v) end
        if type(v)=='string' then return {tag='String',value=v} end
        local fields={}; for i,item in ipairs(v) do fields[i]={value=serialize(item)} end
        return {tag='Table',fields=fields}
    end
    return serialize(code),#code,registers
end
return C

end
modules["vm/runtime"]=function(require)
-- Interpreter source is parsed to AST before insertion. No loadstring/fenv needed.
return [==[(code)
    local r={}
    local pc=1
    local unpackValues=table.unpack or unpack
    if type(unpackValues)~="function" then
        unpackValues=function(t,i,j)
            if i<=j then return t[i],unpackValues(t,i+1,j) end
        end
    end
    while true do
        local ins=code[pc]
        local op=ins[1]
        pc=pc+1
        if op==1 then r[ins[2]]=ins[3]
        elseif op==2 then r[ins[2]]=r[ins[3]]
        elseif op==3 then
            local kind=ins[3]
            local a,b=r[ins[4]],r[ins[5]]
            local value
            if kind=="+" then value=a+b
            elseif kind=="-" then value=a-b
            elseif kind=="*" then value=a*b
            elseif kind=="/" then value=a/b
            elseif kind=="//" then value=a//b
            elseif kind=="%" then value=a%b
            elseif kind=="^" then value=a^b
            elseif kind==".." then value=a..b
            elseif kind=="==" then value=a==b
            elseif kind=="~=" then value=a~=b
            elseif kind=="<" then value=a<b
            elseif kind=="<=" then value=a<=b
            elseif kind==">" then value=a>b
            elseif kind==">=" then value=a>=b
            else error("invalid VM binary opcode",0) end
            r[ins[2]]=value
        elseif op==4 then
            local kind=ins[3]
            local value=r[ins[4]]
            if kind=="not" then r[ins[2]]=not value
            elseif kind=="-" then r[ins[2]]=-value
            elseif kind=="#" then r[ins[2]]=#value
            else error("invalid VM unary opcode",0) end
        elseif op==5 then pc=ins[2]
        elseif op==6 then if not r[ins[2]] then pc=ins[3] end
        elseif op==7 then if r[ins[2]] then pc=ins[3] end
        elseif op==8 then
            local result={}
            local registers=ins[2]
            for i=1,#registers do result[i]=r[registers[i]] end
            return unpackValues(result,1,#registers)
        else error("invalid VM opcode",0) end
    end
end]==]

end
modules["vm/layer"]=function(require)
local Compiler=require('./compiler')
local Runtime=require('./runtime')
local Lexer=require('../lexer')
local Parser=require('../parser')
local A=require('../ast')
local M={}
function M.run(tree,ctx)
    local bytecode,instructions,registers=Compiler.compile(tree)
    local name=ctx:fresh()
    ctx.helpers[#ctx.helpers+1]=Parser.parse(Lexer.lex('local function ' .. name .. Runtime)).body[1]
    ctx.stats.vm_instructions=instructions; ctx.stats.vm_registers=registers
    return A.block({{tag='Return',values={A.call(name,{bytecode})}}})
end
return M

end
modules["main"]=function(require)
local Lexer=require('./lexer')
local Parser=require('./parser')
local Codegen=require('./codegen')
local A=require('./ast')
local Defaults=require('./config')
local Compat=require('./compat')
local Rename=require('./passes/rename')
local Strings=require('./passes/string_encrypt')
local Numbers=require('./passes/number_encrypt')
local Flow=require('./passes/control_flow_flatten')
local Dead=require('./passes/dead_code')
local Wrapper=require('./passes/wrapper')
local VM=require('./vm/layer')
local M={}
function M.obfuscate(source,options)
    assert(type(source)=='string','source must be a string')
    local config={}; for k,v in pairs(Defaults) do config[k]=v end
    for k,v in pairs(options or {}) do assert(Defaults[k]~=nil or k=='dead_code_budget' or k=='control_flow_budget','unknown config: ' .. tostring(k)); config[k]=v end
    for _,k in ipairs({'rename','string_encrypt','number_encrypt','dead_code','wrapper','vm','compat_mode'}) do assert(type(config[k])=='boolean',k .. ' must be boolean') end
    assert(({off=true,light=true,medium=true,heavy=true})[config.control_flow],'invalid control_flow level')
    assert(type(config.seed)=='number' and config.seed%1==0 and config.seed>=0 and config.seed<=2147483647,'seed must be a 31-bit nonnegative integer')
    for _,k in ipairs({'dead_code_budget','control_flow_budget'}) do
        if config[k]~=nil then assert(type(config[k])=='number' and config[k]>=0 and config[k]%1==0 and config[k]<=10000,k .. ' must be an integer from 0 to 10000') end
    end
    assert(type(config.wrapper_functions)=='table','wrapper_functions must be an array')
    for _,name in ipairs(config.wrapper_functions) do assert(type(name)=='string' and name:match('^[%a_][%w_]*$'),'wrapper_functions must contain identifiers') end
    local tree=Parser.parse(Lexer.lex(source))
    local ctx=A.context(tree,config)
    if config.rename then tree=Rename.run(tree,ctx) end
    if config.vm then tree=VM.run(tree,ctx) end
    if config.wrapper then
        assert(config.rename,'wrapper requires rename=true to distinguish locals from globals')
        tree=Wrapper.run(tree,ctx)
    end
    if config.control_flow~='off' and not config.vm then tree=Flow.run(tree,ctx) end
    if config.dead_code then tree=Dead.run(tree,ctx) end
    if config.number_encrypt then tree=Numbers.run(tree,ctx) end
    if config.string_encrypt then tree=Strings.run(tree,ctx) end
    local body={}
    if config.compat_mode then body[#body+1]={tag='Do',body=A.block({Compat.inject(ctx)})} end
    for _,helper in ipairs(ctx.helpers) do body[#body+1]=helper end
    for _,s in ipairs(tree.body) do body[#body+1]=s end
    tree.body=body
    return Codegen.generate(tree),{stats=ctx.stats,warnings=ctx.warnings,ast=tree}
end
M.parse=function(source) return Parser.parse(Lexer.lex(source)) end
M.generate=Codegen.generate
return M

end
local cache={}
local function normalize(base,path)
    local parts={}
    for part in string.gmatch(base..'/'..path,'[^/]+') do
        if part=='..' then assert(#parts>0,'invalid module path'); parts[#parts]=nil
        elseif part~='.' then parts[#parts+1]=part end
    end
    return table.concat(parts,'/')
end
local function loadModule(id)
    if cache[id]~=nil then return cache[id] end
    local factory=assert(modules[id],'unknown bundled module '..id)
    local dir=id:match('^(.*)/') or ''
    local value=factory(function(path) return loadModule(normalize(dir,path)) end)
    cache[id]=value
    return value
end
return loadModule('main')
