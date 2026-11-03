// CodeMirror fivem-cfg syntax highlight
// Originally written by Tabarra for https://github.com/tabarra/txAdmin
// Rewritten as a context-aware mode: tokens are classified based on their
// position in the command (command name, first argument, other arguments).

(function () {
    const words = (str) => new Set(str.split(/\s+/).filter(Boolean).map((w) => w.toLowerCase()));

    // Commands that control resources
    const resourceCmds = words('start stop ensure restart refresh');
    // Commands that set convars (first arg = convar name)
    const convarCmds = words('set seta setr sets');
    // Permission system commands (first arg = principal/identifier)
    const aceCmds = words('add_ace remove_ace add_principal remove_principal test_ace');
    // Other well-known commands
    const builtinCmds = words(`
        exec quit wait endpoint_add_tcp endpoint_add_udp load_server_icon
        sv_hostname sv_licenseKey sv_maxClients sv_maxclients sv_master1 sv_endpointPrivacy
        sv_scriptHookAllowed sv_enforceGameBuild sv_authMaxVariance sv_authMinTrust
        sv_projectName sv_projectDesc sv_pureLevel sv_lan rcon_password gamename onesync
        steam_webApiKey tags locale banner_connecting banner_detail sv_filterRequestControl
    `);
    const constants = words('true false on off allow deny legacy');
    const principalPrefix = /^(?:group|identifier|resource|builtin|command|license|license2|steam|discord|fivem|xbl|live|ip)[.:]/i;
    const numberRe = /^(?:0x[\da-f]+|[-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?)$/i;

    CodeMirror.defineMode('fivem-cfg', function () {
        return {
            startState: () => ({ argIndex: 0, cmd: null, inBlockComment: false }),
            copyState: (s) => ({ ...s }),

            token: function (stream, state) {
                if (stream.sol()) {
                    state.argIndex = 0;
                    state.cmd = null;
                }

                // Multi-line /* */ comment
                if (state.inBlockComment) {
                    if (stream.skipTo('*/')) {
                        stream.next(); stream.next();
                        state.inBlockComment = false;
                    } else {
                        stream.skipToEnd();
                    }
                    return 'comment';
                }

                if (stream.eatSpace()) return null;

                // Line comments
                if (stream.match('#') || stream.match('//')) {
                    stream.skipToEnd();
                    return 'comment';
                }
                if (stream.match('/*')) {
                    state.inBlockComment = true;
                    return 'comment';
                }

                // Command separator
                if (stream.eat(';')) {
                    state.argIndex = 0;
                    state.cmd = null;
                    return 'operator';
                }

                const argIndex = state.argIndex++;
                const cmd = state.cmd;

                // Quoted strings
                const quote = stream.peek();
                if (quote === '"' || quote === "'") {
                    stream.next();
                    let escaped = false, ch;
                    while ((ch = stream.next()) != null) {
                        if (ch === quote && !escaped) break;
                        escaped = !escaped && ch === '\\';
                    }
                    if (argIndex === 0) state.cmd = '';
                    return 'string';
                }

                // Bare word (stops at whitespace, quotes, separators and comments)
                stream.match(/^(?:[^\s"';#/]|\/(?![/*]))+/) || stream.next();
                const word = stream.current();
                const lower = word.toLowerCase();

                // Command name
                if (argIndex === 0) {
                    state.cmd = lower;
                    if (resourceCmds.has(lower) || convarCmds.has(lower) || aceCmds.has(lower)) return 'keyword';
                    if (builtinCmds.has(lower)) return 'builtin';
                    return 'def';
                }

                // First argument, depends on command
                if (argIndex === 1) {
                    if (resourceCmds.has(cmd)) return 'variable-2';
                    if (convarCmds.has(cmd)) return 'property';
                    if (cmd === 'exec') return 'string-2';
                }

                if (constants.has(lower)) return 'atom';
                if (numberRe.test(word)) return 'number';
                if (principalPrefix.test(word)) return 'variable-3';
                return 'variable';
            },

            lineComment: '#',
            blockCommentStart: '/*',
            blockCommentEnd: '*/',
        };
    });

    CodeMirror.defineMIME('text/x-fivem-cfg', 'fivem-cfg');
})();
