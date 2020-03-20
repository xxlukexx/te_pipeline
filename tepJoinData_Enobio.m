function tepJoinData_Enobio(varargin)

    % instantiate a teExternalData instance for each file
    teEcho('Attempting to load raw data from each .easy file...\n');
    ext = cellfun(@teExternalData_Enobio, varargin, 'UniformOutput', false);
    
    if ~all(cellfun(@(x) x.Valid, ext))
        error('At least one .easy file couldn''t be loaded.')
    end
    
    % try to load all .easy data into memory
    try
        dat = cellfun(@(x) load(x.Paths('enobio_easy')), ext, 'UniformOutput', false);
    catch ERR
        error('Error loading one dataset:\n\n%s', ERR.message)
    end
    
    % find first sample and length of all datasets
    firstSamp = cellfun(@(x) x(1, end), dat);
    len = cellfun(@(x) size(x, 1), dat);
    
    % plot
    onset = firstSamp;
    offset = onset + len;
    figure('toolbar', 'none');
    for d = 1:length(ext)
        
        % box
        x1 = onset(d);
        x2 = offset(d);
        y1 = d;
        y2 = 1;
        rectangle('position', [firstSamp(d), 1, len(d), 1])
        
        % date time string
        [~, fileName, fileExt] = fileparts(varargin{d});
        fileStr = [fileName, fileExt];
        onStr = char(datetime(firstSamp(d) / 1e3, 'ConvertFrom', 'posixtime'));
        offStr = char(datetime((firstSamp(d) + len(d)) / 1e3, 'ConvertFrom', 'posixtime'));
        durStr = len(d) / 1e3 / 60;
        onOffStr = sprintf('%s\nOnset: %s\nOffset: %s\nDuration: %.1fm', fileStr, onStr, offStr, durStr);
        text('Position', [firstSamp(d) + (len(d) / 2), 1.5], 'String', onOffStr, 'HorizontalAlignment', 'center', 'Interpreter', 'none')
    end
    box('off')
    set(gca, 'YTick', [])
    ylim([0, 3])
    
    % backup entire enobio folder. First copy to temp file then move back
    % to enobio 
    teEcho('Backing up old files...\n');
    path_enobio = fileparts(ext{1}.Paths('enobio_easy'));
    path_zip = tempdir;
    file_zip = sprintf('precombine_%s.zip', fileName);
    zip(fullfile(path_zip, file_zip), path_enobio)
    copyfile(fullfile(path_zip, file_zip), fullfile(path_enobio, file_zip))
    
    % cat data files
    dataOut = vertcat(dat{:});
    [~, so] = sort(dataOut(:, end));
    dataOut = dataOut(so, :);
    firstSampOut = dataOut(1, end);
    lenOut = size(dataOut, 1);
    
    % edit .info file
    inf = fileread(ext{1}.Paths('enobio_info'));
    inf = strrep(inf, num2str(firstSamp(1)), num2str(firstSampOut));
    inf = strrep(inf, num2str(len(1)), num2str(lenOut));
    
    % delete old files
    cellfun(@(x) delete(x.Paths('enobio_easy')), ext)
    cellfun(@(x) delete(x.Paths('enobio_info')), ext)
    
    % write new info file
    teEcho('Saving joined .info file to: %s\n', ext{1}.Paths('enobio_info'))
    fid = fopen(ext{1}.Paths('enobio_info'), 'w+');
    fprintf(fid, '%s', inf);
    fclose(fid)
    
    % write new easy file
    teEcho('Saving joined .easy file to: %s\n', ext{1}.Paths('enobio_easy'));
    writetable(array2table(dataOut), ext{1}.Paths('enobio_easy'), 'WriteVariableNames', false, 'FileType', 'text')
    
    
end