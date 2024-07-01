function [merged, ops] = teJoin_eyeTracking(varargin)
% takes any number of split eye tracking datasets and joins them into one
% dataset

    ops = operationsContainer;
    
    % attempt to load all input datasets
    num_data = length(varargin);
    et = cell(num_data, 1);
    load_success = false(num_data, 1);
    guid = cell(num_data, 1);
    sr = nan(num_data, 1);
    
    for d = 1:num_data
        et{d} = teExternalData_EyeTracking(varargin{d});
        load_success(d) = et{d}.InstantiateSuccess;
        guid{d} = et{d}.GUID;
        if ~isempty(et{d}.TargetSampleRate)
            sr(d) = et{d}.TargetSampleRate;
        end
    end
    
    % check that everything loaded correctly
    if ~all(load_success)
        fprintf(2, 'Some (%d) eye tracking datasets did not load correctly:\n\n',...
            sum(~load_success))
        for d = 1:num_data
            if ~load_success(d)
                fprintf(2, '\t%s: %s\n', varargin{d}, et{d}.InstantiateOutcome)
            end
        end
        fprintf('\n\n')
        error('Error loading eye tracking data.')
    end
    
    % check that GUIDs match and warn if not
    if length(unique(guid)) ~= 1
        warning('Not all eye tracking GUIDs match.')
    end
    
    % check that sample rates match
    if ~all(isnan(sr)) && length(unique(sr)) ~= 1
        fprintf(2, 'Mismatched sample rates:\n\n')
        for d = 1:num_data
            fprintf(2, '\t%s: %dHz\n', varargin{d}, sr(d))
        end
        fprintf('\n\n')
        error('Mismatched sample rates.')
    end
    
    % merge
    
        % Initialize mergedDataset with the first dataset
        merged = et{1};

        for i = 2:num_data
            
            current_data = et{i};

            % Extract timestamps from mergedDataset and currentDataset
            t_merged = merged.Buffer(:, 1);
            t_current = current_data.Buffer(:, 1);

            % Find common timestamps
            t_common = intersect(t_merged, t_current);

            if ~isempty(t_common)
                % Check for identical data in overlapping sections
                for j = 1:length(t_common)
                    % Find rows with the current timestamp in both datasets
                    row_merged = merged.Buffer(t_merged == t_common(j), :);
                    row_current = current_data.Buffer(t_current == t_common(j), :);

                    % Check if rows are identical. isequal doesn't work
                    % properly, so subtract the two rows and make sure the
                    % difference is all zero or all NaN
                    row_compare = row_merged - row_current;
                    if ~all(isnan(row_compare) | row_compare == 0)
                        error('Overlap detected with non-identical data in datasets %d and %d.', i-1, i);
                    end
                end

                % Removing duplicates from the current dataset
                [~, idx] = ismember(t_common, t_current);
                current_data.Buffer(idx, :) = [];
            end

            % Concatenate the current dataset
            merged.Buffer = [merged.Buffer; current_data.Buffer];

        end
    
end