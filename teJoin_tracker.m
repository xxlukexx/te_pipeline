function [tracker_joined, ops] = teJoin_tracker(varargin)
% takes any number of split eye tracking datasets and joins them into one
% dataset
    
    % attempt to load all input datasets
    num_data = length(varargin);
    tracker = cell(num_data, 1);
    dynamic_vars = cell(num_data, 1);
    suc = false(num_data, 1);
    oc = cell(num_data, 1);    
    ops = operationsContainer;
    
    for d = 1:num_data
        
        path_current_tracker = varargin{d};
        
        % attempt to load, catch errors and check data type
        try
            
            tmp = load(varargin{d});
            suc(d) = true;
            
            % does the file have a "tracker" variable?
            if ~isfield(tmp, 'tracker') 
                suc(d) = false;
                oc{d} = sprintf('%s: No tracker variable found in data file', path_current_tracker);
            end
            
            % is the tracker variable serialised? 
            if suc(d) && isa(tmp.tracker, 'uint8') && isvector(tmp.tracker)
                % attempt to deserialise
                try
                    tmp.tracker = getArrayFromByteStream(tmp.tracker);
                catch ERR
                    suc(d) = false;
                    oc{d} = sprintf('%s: Failed to deserialise', path_current_tracker);
                end
            end
            
            % does the file contain a teTracker?
            if suc(d) && ~isa(tmp.tracker, 'teTracker')
                suc(d) = false;
                oc{d} = sprintf('%s: Not a teTracker instance', path_current_tracker);
            end
            
        catch ERR
            
            suc(d) = false;
            oc{d} = sprintf('%s: %s', ERR.message);
            
        end
        
        % store the data
        tracker{d} = tmp.tracker;     
        dynamic_vars{d} = tmp.tracker.GetVariables;
        
    end
    
    if ~all(suc)
        fprintf(2, 'Some (%d) tracker files failed to load:\n\n', sum(~suc))
        for d = 1:num_data
            if ~suc(d)
                fprintf(2, '\t%s: %s\n', varargin{d}, oc{d})
            end
            fprintf('\n\n')
            error('Error loading trackers.')
        end
    end
    
    % check that dynamic variables match across datasets
    if ~isequal(dynamic_vars{:})
        ops.AddWarning('Dynamic variables do not match between datasets')
    end
    
    % create copy of first tracker, the rest will be appended to this
    tracker_joined = copyHandleClass(tracker{1});
    tracker_joined.Log = [];
    
    % join
    [suc_join, oc_join, tracker_joined] = join_log(tracker_joined, tracker{:});
     
end

function [suc, oc, tracker_joined] = join_log(tracker_joined, varargin)
    % takes an output tracker (tracker_joined) and all input trackers, and
    % combines the logs from each into the output tracker. Logs are combined by
    % finding the temporal extent of each the log in each tracker, and
    % calculating where there is overlap. Where there isn't overlap,
    % non-overlapping log entries are copied to the joined tracker. 

        teEcho('Joining log data...\n');

        suc = false;
        oc = 'unknown error';
        allTrackers = varargin;
        numData = length(allTrackers);

    % find temporal extent of all tracker logs

        t_ext = nan(numData, 2);
        for d = 1:numData

            % sort log entries
            la = teSortLog(allTrackers{d}.Log);

            % find temporal extent
            t_ext(d, 1) = la{1}.timestamp;
            t_ext(d, 2) = la{end}.timestamp;

        end

    % find log duration and sort in descending order

        dur_ext = t_ext(:, 2) - t_ext(:, 1);
        [~, so] = sort(t_ext(:, 2), 'descend');
        allTrackers = allTrackers(so);
        t_ext = t_ext(so, :);
        dur_ext = dur_ext(so);

    % loop through trackers and copy to joined tracker, if extents DON'T
    % overlap 

        for d = 1:numData

            if d == 1

                % this is the master tracker with the longest log. Do a
                % straight copy, regardless of extent
                tracker_joined.Log = allTrackers{d}.Log;

            else

                % get log timestamps
                ts = cellfun(@(x) x.timestamp, allTrackers{d}.Log);

                % find entries that don't overlap with the master log (i.e.
                % they come before the start of the master, or after the end)
                idx_before = ts < t_ext(1, 1);
                idx_after = ts > t_ext(1, 2);

                % if any logs need to be appended, prepare them and insert
                % boundary events
                if any(idx_before)

                    % create boundary event, and cat to END of to-be-copied log
                    li_boundary = struct('timestamp', ts(find(idx_before,1 , 'last')),...
                        'topic', 'join_boundary',...
                        'source', 'teJoin_log',...
                        'ses_before', allTrackers{d}.Path_Session,...
                        'ses_after', allTrackers{1}.Path_Session);

                    % join all elements of the log that are needed on to the
                    % boundary event
                    la_before = [allTrackers{d}.Log(idx_before); {li_boundary}];

                    % join
                    allTrackers{1}.Log = [la_before; allTrackers{1}.Log];

                end

                % if any logs need to be appended, prepare them and insert
                % boundary events
                if any(idx_after)

                    % create boundary event, and cat to END of to-be-copied log
                    li_boundary = struct('timestamp', ts(find(idx_after, 1)),...
                        'topic', 'join_boundary',...
                        'source', 'teJoin_log',...
                        'ses_before', allTrackers{1}.Path_Session,...
                        'ses_after', allTrackers{d}.Path_Session);

                    % join all elements of the log that are needed on to the
                    % boundary event
                    la_after = [{li_boundary}; allTrackers{d}.Log(idx_after)];

                    % join
                    allTrackers{1}.Log = [allTrackers{1}.Log; la_after];

                end            

                % re-sort master, and calculate new extents
                allTrackers{1}.Log = teSortLog(allTrackers{1}.Log);

                % find temporal extent
                t_ext(1, 1) = allTrackers{1}.Log{1}.timestamp;
                t_ext(1, 2) = allTrackers{1}.Log{end}.timestamp;

            end

        end

        tracker_joined.Log = allTrackers{1}.Log;

        suc = true;
        oc = '';

    end   