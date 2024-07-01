function [tab_session, tab_all_sessions] = teMakeSessionTimingFramework(varargin)
% takes a number of session paths as a input arguments, finds any possible
% data within the session folder, categorise it (e.g. "log", "enobio" etc)
% and find the temporal extent (onset and offset times) for it. 
% 
% this can be passed to tePlotSessionTimingFramework to visualise the
% results

    % check input args
    if ~all(cellfun(@ischar, varargin)) ||...
            ~all(cellfun(@(x) exist(x, 'dir'), varargin))
        error('All input arguments must be strings containing paths to session folders')
    end
    
    [tab_session, tab_all_sessions] = parse_data(varargin{:});
        
    function [tab, tab_all] = parse_data(varargin)
        
        % loop through all session folders
        num_ses = length(varargin);
        tab = cell(num_ses, 1);                                                 % store per-session results in table
        for s = 1:num_ses

            % get contents of this session folder
            path_ses = varargin{s};
            d_ses = recdir(path_ses);                                           % contains all files and folders per session
            num_files = length(d_ses);                                          
            res_ses = cell(num_files, 1);                                       % outcome of scan of data
            t = nan(num_files, 2);                                              % timestamps [start, end]
            valid = false(num_files, 1);                                        % valid for plotting?

            for f = 1:num_files

                % if this is a folder, skip
                path_file = d_ses{f};
                if isfolder(path_file)
                    res_ses{f} = 'folder';
                    continue
                end

                % get file extension
                [~, ~, ext] = fileparts(path_file);

                % parse file extension
                switch ext

                    case '.mat'

                        % mat file, attempt to load then pass to the read_mat
                        % function for further inspection
                        try
                            tmp = load(path_file);
                            [suc, oc, t1, t2, data_type] = read_mat(tmp);
                            if ~suc
                                res_ses{f} = oc;
                            else
                                res_ses{f} = data_type;
                                t(f, :) = [t1, t2];
                                valid(f) = true;
                            end
                        catch ERR
                            res_ses{f} = ERR.message;
                        end

%                     case '.easy'
% 
%                         try
%                             tmp = load(path_file);
%                             [suc, oc, t1, t2, data_type] = read_easy(tmp);
%                             if ~suc
%                                 res_ses{f} = oc;
%                             else
%                                 res_ses{f} = data_type;
%                                 t(f, :) = [t1, t2];
%                                 valid(f) = true;
%                             end
%                         catch ERR
%                             res_ses{f} = ERR.message;
%                         end
                        
                    case '.info'

                        try
                            [suc, oc, t1, t2, data_type] = read_info(path_file);
                            if ~suc
                                res_ses{f} = oc;
                            else
                                res_ses{f} = data_type;
                                t(f, :) = [t1, t2];
                                valid(f) = true;
                            end
                        catch ERR
                            res_ses{f} = ERR.message;
                        end                        

                    otherwise

                        % unrecognised/unsupport/ignored data type
                        res_ses{f} =...
                            sprintf('unrecognised or ignored data format (%s)', ext);

                end

            end

            tab{s} = table;
            tab{s}.path = d_ses;
            tab{s}.result = res_ses;
            tab{s}.t1 = t(:, 1);
            tab{s}.t2 = t(:, 2);
            tab{s}.valid = valid;

        end
        
        % Append session number to each table
        num_ses = length(tab);
        for s = 1:num_ses
            tab{s}.session = repmat(s, size(tab{s}, 1), 1);
        end

        % Combine into one table
        tab_all = vertcat(tab{:});

        % Remove files that don't have valid times associated with them
        tab_all = tab_all(tab_all.valid, :);
    
    
    end

    function [suc, oc, t1, t2, data_type] = read_mat(tmp)
        
        suc = false;
        oc = 'unknown error';
        t1 = nan;
        t2 = nan;
        data_type = 'unrecognised';
        
        % look for recognisable fields that indicate a particular data type
        field_names = fieldnames(tmp);
        num_fields = length(field_names);
        for i = 1:num_fields
            
            % check for serialised data and deserialise
            val = tmp.(field_names{i});
            if isa(val, 'uint8') && isvector(val)
                try
                    val = getArrayFromByteStream(val);
                catch ERR
                    suc = false;
                    oc = ERR.message;
                    return
                end
            end
            
            % determine data type
            
            switch class(val)
                
                case 'teTracker'
                    
                    if strcmpi(field_names{i}, 'tracker')
                        
                        if isprop(val, 'Log')
                            
                            % pull time 1 and 2 from the log entries
                            t1 = val.Log{1}.timestamp;
                            t2 = val.Log{end}.timestamp;
                            data_type = 'log';
                            
                        end
                        
                    end
                
                case {'struct', 'teExternalData_EyeTracking'}
                    
                    if strcmp(field_names{i}, 'eyetracker')
                        
                        if isfield(val, 'Buffer') || isprop(val, 'Buffer')
                            
                            % pull time 1 and 2 from the eye tracker
                            % timestamps in the data buffer
                            t1 = val.Buffer(1, 1);
                            t2 = val.Buffer(end, 1);
                            data_type = 'eyetracking';
            
                        end
                        
                    end
                    
                otherwise
                    
                    % unrecognised
                    suc = false;
                    oc = 'unrecognised data';
                    return
                   
            end
            
        end
        
        suc = true;
        oc = '';
        
    end
    
    function [suc, oc, t1, t2, data_type] = read_easy(tmp)
        
        suc = false;
        oc = 'unknown error';
        t1 = nan;
        t2 = nan;
        data_type = 'unrecognised';
        
        % check that the data looks like enobio data
        if isnumeric(tmp) && ismatrix(tmp) 
            
            % if this is enobio, timestamps should be the last column
            t1 = tmp(1, end);
            t2 = tmp(end, end);
            data_type = 'enobio';
            
        end

        suc = true;
        oc = '';
        
    end

    function [suc, oc, t1, t2, data_type] = read_info(path_info)

        % Initialize output variables
        suc = false;
        oc = 'unknown error';
        t1 = nan;
        t2 = nan;
        data_type = 'unrecognised';

        try
            % Open the file for reading
            fid = fopen(path_info, 'rt');
            if fid == -1
                oc = 'File cannot be opened';
                return;
            end
            
            sampling_rate = nan;

            % Read the file line by line
            while ~feof(fid)
                line = fgetl(fid);

                % Find the first timestamp
                if contains(line, 'StartDate (firstEEGtimestamp):')
                    t1_str = strtrim(extractAfter(line, 'StartDate (firstEEGtimestamp):'));
                    t1 = str2double(t1_str) / 1000;
                end

                % Find the number of EEG records
                if contains(line, 'Number of records of EEG:')
                    num_records_str = strtrim(extractAfter(line, 'Number of records of EEG:'));
                    num_records = str2double(num_records_str);
                end

                % Find the EEG sampling rate
                if contains(line, 'EEG sampling rate:') && isnan(sampling_rate)
                    sampling_rate_str = strtrim(extractAfter(line, 'EEG sampling rate:'));
                    sampling_rate = str2double(extractBefore(sampling_rate_str, ' Samples/second'));
                end
            end

            % Close the file
            fclose(fid);

            % Calculate the last timestamp
            if ~isnan(t1) && ~isnan(num_records) && ~isnan(sampling_rate)
                duration_seconds = num_records / sampling_rate;
                t2 = t1 + duration_seconds;
                data_type = 'enobio';
                suc = true;
                oc = '';
            else
                oc = 'Required information not found in the file';
            end

        catch
            oc = 'Error occurred while reading the file';
            if fid ~= -1
                fclose(fid);
            end
        end

    end
    
end