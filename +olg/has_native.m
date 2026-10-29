function present=has_native(name)
root=fileparts(fileparts(mfilename('fullpath')));
present=isfile(fullfile(root,'+olg','+fast',[name '.' mexext]));
end
