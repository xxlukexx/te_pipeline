classdef tepJobManager < handle
    
    properties (SetAccess = private)
        Jobs teCollection
        Diary
        JobTable
    end
    
    properties (Dependent, SetAccess = private)
        NumJobs
        NumFinished
        Operations
    end
    
    properties (Access = private)
        newJobLabelIdx = 1
        fut 
        stat cmdStatus
        h_table
        runJobsOnset
    end
    
    methods
        
        function obj = tepJobManager
            obj.Jobs = teCollection('hstruct');            
        end
        
        function AddJob(obj, fcn, numOut, label, varargin)
            
            % if no label passed, assign one
            if ~exist('label', 'var') || isempty(label)
                label = sprintf('job_%02d', obj.newJobLabelIdx);
                obj.newJobLabelIdx = obj.newJobLabelIdx + 1;
            else
                if ~isstring(label)
                    error('''label'' must be a string.')
                end
            end
            
            if ~isnumeric(numOut) || ~isscalar(numOut) || numOut < 1
                error('''numOut'' must be a numeric scalar > 1.')
            end
            
            if ischar(fcn)
                fcn = str2func(fcn);
            end
            
            % create blank data entries 
            s = hstruct;
            s.state = 'not_started';
            s.fcn = fcn;
            s.numOut = numOut;
            s.args = varargin;
            s.result = [];
            s.error = 'none';
            obj.Jobs(label) = s;
            
            obj.UpdateUITable
            
        end
        
        function RunJobs(obj, idx)
            
            if ~exist('idx', 'var') || isempty(idx)
                idx = true(obj.Jobs.Count, 1);
            end
            
            % check that all functions can run before trying to send them
            % to workers. This prevents potentially very slow Matlab
            % responses when sending jobs to workers
            
                % get the function name and job labels for all jobs
                tab = teLogExtract(obj.Jobs.Items);
                fcn = cellfun(@char, tab.fcn, 'uniform', false);
                lab = obj.Jobs.Keys';
                
                % flag any entries with functions that don't exist
                problem = cellfun(@(x) exist(char(x)), tab.fcn) == 0;
                
                % throw an error if any were found
                if any(problem)
                    fprintf(2, '%d jobs have been set to call a function that Matlab reports does not exist. These are:\n\n',...
                        sum(problem));
                    cellfun(@(x, y) fprintf(2, '\t%s (@%s)\n', x, y),...
                        lab(problem), fcn(problem))
                    error('Cannot run jobs with functions that do not exist.')
                end
            
            % record onset time
            obj.runJobsOnset = teGetSecs;
            
            % make UI
            obj.UI
            
            % make command line status object
            obj.stat = cmdStatus(sprintf(...
                'Sending %d jobs to parallel workers.\n', obj.NumJobs));
            
            % preallocate parallel futures
            obj.fut = repmat(parallel.FevalFuture, obj.NumJobs, 1);
            
            % loop through all jobs and send them to parallel workers
            for j = 1:obj.NumJobs
                
                % support processing by index
                if ~idx(j), continue, end
                
                % get data for this job
                s = obj.Jobs(j);
                
                % execute
                argsToExecute = s.args;
                obj.fut(j) = parfeval(s.fcn, s.numOut, argsToExecute{:});
                
                % update state and status
                s.state = 'running';
                obj.stat.Status =...
                    sprintf('Sent job %d of %d to parallel workers (%.2f%%)...',...
                    j, obj.NumJobs, (j / obj.NumJobs) * 100);
                
            end

            obj.UpdateUITable
            obj.stat.Status = 'Waiting to receive first job from parallel worker...';
            
            % loop until all jobs are finished. Whist looping, monitor all
            % jobs to look for ones that have finished
            obj.Diary = cell(obj.NumJobs, 1);
            onset = teGetSecs;
            while obj.NumFinished < obj.NumJobs
                
                % loop through all jobs
                for f = 1:length(obj.fut)
                    
                    % has it finished?
                    if strcmpi(obj.fut(f).State, 'finished')
                        
                        % prepare for outputs by reading number of ouput
                        % args for this job
                        numOut = obj.fut(f).NumOutputArguments;
                        
                        % get storage for this job
                        s = obj.Jobs(f);
                        
                        % if an error occurred, catch it and store the
                        % message. Otherwise, fetch the outputs from the
                        % parallel future and store in the data
                        if ~isempty(obj.fut(f).Error)
                            s.error = obj.fut(f).Error.message;
                        else
                            tmpResult = cell(1, numOut);
                            [tmpResult{:}] = obj.fut(f).fetchOutputs;  
                            obj.Diary{f} = obj.fut(f).Diary;
                            s.result = tmpResult;                         
                            s.error = 'none';
                        end
                        s.state = 'finished';                            
                        
                        % every second, update the UI table with current
                        % progress
                        if teGetSecs - onset > 1
                            
                            obj.UpdateUITable
                            onset = teGetSecs;
                            
                            obj.stat.Status = obj.calculateProgress;
                        
                        end
                        
                    end
                    
                end
               
            end

            elap = teGetSecs - obj.runJobsOnset;
            elap_str = datestr(elap / 86400, 'HH:MM:SS');
            obj.stat.Status =...
                sprintf('Finished running %d jobs in %s.\n',...
                obj.NumJobs, elap_str);
            
            obj.UpdateUITable
            
        end
        
        function UI(obj, varargin)
            
            [data_cell, vars] = obj.createUITableData;
            
            % make uitable
            h = uitable('data', data_cell,...
                'ColumnName', vars,...
                'FontSize', 12,...
                'Units', 'normalized',...
                'Position', [0, 0, 1, 1],...
                'CellSelectionCallback', @obj.uitable_click,...
                varargin{:});            

%             obj.sizeTableColumns(h)
            obj.h_table = h;          
            drawnow
            
        end
        
        function UpdateUITable(obj)
            
            if ~isempty(obj.h_table) && isvalid(obj.h_table)
                [data_cell, vars] = obj.createUITableData;
                obj.h_table.ColumnName = vars;
                obj.h_table.Data = data_cell;
                obj.JobTable = cell2table(data_cell, 'VariableNames', vars);
                drawnow
            end
            
        end
                
        function c = SanitiseResults(obj)
            
            if isempty(obj.Operations)
                c = [];
                return
            end
            
            if ~ismember(obj.Operations.Properties.VariableNames, 'result')
                c = [];
                return
            end
            
            c = obj.Operations.result;
            numRows = height(c);
            numCols = width(c);
            for row = 1:numRows
                for col = 1:numCols
                    
                    if iscell(c{row, col}) && ~isempty(c{row, col})
                        c{row, col} = c{row, col}{1};
                    end
                    
                end
            end
            
        end
        
        % get/set
        function val = get.NumJobs(obj)
            val = obj.Jobs.Count;
        end
        
        function val = get.NumFinished(obj)
            if isempty(obj.Jobs)
                val = 0;
                return
            end
            tab = teLogExtract(obj.Jobs.Items);
            val = sum(strcmpi(tab.state, 'finished'));
        end
        
        function val = get.Operations(obj)
            if isempty(obj.Jobs)
                val = [];
            else
                val = teLogExtract(obj.Jobs.Items);
            end
        end
                
    end
    
    methods (Access = private)
        
        function sizeTableColumns(~, h)
            
            uitableAutoColumnHeaders(h)
            h.Units = 'pixels';
            valColWidth = h.Position(3) - h.ColumnWidth{1};
            if valColWidth < 0, valColWidth = 100; end
            h.Units = 'normalized';
            h.ColumnWidth{2} = valColWidth;
            h.RowName = [];
            
        end
        
        function [data_cell, vars] = createUITableData(obj)
            
            fcnVal = @(x) ischar(x) ||...
                (isscalar(x) && (isnumeric(x) || islogical(x)));
            % attempt to expand results into data
%             items = copyHandleClass(obj.Jobs.Items);
            items = cell(size(obj.Jobs.Items));
            for i = 1:length(items)
                items{i} = struct(obj.Jobs.Items{i});
                res = items{i}.result;
                if ~isempty(res)
                    
                    if ~iscell(res)
                        res = {res};
                    end
                    
                    for e = 1:length(res)
                        
                        var = sprintf('result%03d', e);
                        
                        % numeric
                        if fcnVal(res{e})
                            items{i}.(var) = res{e};
                        end
                    
                        % teMetadata
                        if isa(res{e}, 'teMetadata')
                            s = struct(res{e});
                            idx_val = ~structfun(fcnVal, s);
                            fields = fieldnames(s);
                            s = rmfield(s, fields(idx_val));
                            items{i} = catstruct(items{i}, s, var);
                        end
                        
                    end
                    
                end
            end
            
            % convert to table
            tab = teLogExtract(items);
            if isempty(tab)
                data_cell = [];
                vars = [];
                return
            end
            
            % apply colours
            tab.state = strrep(tab.state, 'finished', '<html><font color="#33cc33">finished');
            tab.state = strrep(tab.state, 'running', '<html><font color="#cca633">running');
            idx_error = ~strcmp(tab.error, 'none');
            tab.error(idx_error) = cellfun(@(x) sprintf('<html><font color="#cca633">%s', x),...
                tab.error(idx_error), 'UniformOutput', false);
            
            % convert arguments to char
            args = tab.args;
            idx_args = cellfun(fcnVal, args);
            args(~idx_args) = cellfun(@(x) sprintf('#%s', class(x)), args(~idx_args), 'UniformOutput', false);
            tab.args = cell(height(tab), 1);
            for r = 1:height(args)
                tab.args{r} = cell2char(args(r, :), ' | ');
            end
            
            % remove unwanted
            tab.result = [];
%             tab.args = [];
            tab.numOut = [];
            tab.logIdx = [];
            tab.fcn = cellfun(@char, tab.fcn, 'uniform', false);
            tab = movevars(tab, {'fcn', 'args', 'state', 'error'}, 'before', 1);
            vars = tab.Properties.VariableNames;
            data_cell = table2cell(tab);
            
            % replace empty with empty string
            idx_empty = cellfun(@isempty, data_cell);
            data_cell(idx_empty) = repmat({' '}, sum(idx_empty(:)), 1);
            
        end
        
        function [formattedProgress, numFinished, numLeft, percFinished, timeElapsed,...
                timeLeft] = calculateProgress(obj)
            
            tab = teLogExtract(obj.Jobs.Items);
            numFinished = sum(strcmpi(tab.state, 'finished'));
            numLeft = size(tab, 1) - numFinished;
            percFinished = (numFinished / size(tab, 1)) * 100;
            timeElapsed = teGetSecs - obj.runJobsOnset;
            timePerJob = timeElapsed / numFinished;
            timeLeft = timePerJob * numLeft;
            timeLeftStr = datestr(timeLeft / 86400, 'HH:MM:SS');
            formattedProgress = sprintf('%d jobs of %d finished, %d remaining, %s remaining',...
                numFinished, size(tab, 1), numLeft, timeLeftStr);
            
        end
        
        function uitable_click(obj, h, event)
            
            
        end
            
    end    
    
end