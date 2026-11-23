" The Cloud Query API authenticates through clickhousectl's stored credentials.
function! db#adapter#lumin#input(url, file) abort
  return [expand('~/.config/nvim/scripts/chq'), a:file]
endfunction

function! db#adapter#lumin#auth_input() abort
  return v:false
endfunction
