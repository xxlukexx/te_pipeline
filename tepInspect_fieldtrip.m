function [md, tracker] = tepInspect_fieldtrip(ext, md, tracker, varargin)

    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.tepInspect_fieldtrip.success = false;
        md.tepInspect_fieldtrip.outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    % check file exists
    if ~exist(ext.Paths('fieldtrip'), 'file')
        md.tepInspect_fieldtrip.success = false;
        md.tepInspect_fieldtrip.outcome =...
            sprintf('cannot find fieldtrip file at: %s',...
            ext.Paths('fieldtrip'));
        return
    end
    
    % find first and last timestamp in ft data
    tmp = load(ext.Paths('fieldtrip'));
    md.Checks.fieldtrip_t1 = tmp.ft_data.abstime(1);
    md.Checks.fieldtrip_t2 = tmp.ft_data.abstime(end);
    
    % check for no events
    if isempty(tmp.ft_data.events)
        md.fieldtrip.hasEvents = false;
        md.tepInspect_fieldtrip.success = false;
        md.tepInspect_fieldtrip.outcome = 'no events in EEG data';        
        return
    else
        md.fieldtrip.hasEvents = true;
    end
    
    % check for light sensor
    [found_ls, idx_ls] = eegFT_findLightSensorChannel(tmp.ft_data);
    md.fieldtrip.hasLightSensor = found_ls;
    if found_ls
        md.fieldtrip.lightSensorChannelIdx = find(idx_ls);
        md.fieldtrip.lightSensorChannelLabel = tmp.ft_data.label{idx_ls};
    else
        % do we need to fill this with blank/empty vars for light sensor
        % idx and channel label? Or is this handled by logicalstruct?
    end
    
    % sync
    
        % determine type of events -- see descriptions below
        if ~isempty(teLogFilter(tracker.Log, 'source', 'teEventRelay_enobio_linked'))
            
            % events were sent using linked indices. Each task engine event
            % was sent to the log, and an incrementing index sent to the
            % EEG. 
            syncFun = 'teSyncEEG_fieldtrip_linked';
            teEcho('tepInspect_fieldtrip: detected linked index events.\n');
            
        else
            
            % events were sent with a normal event relay, which means that
            % a numeric event was sent to the EEG, and a normal task engine
            % event sent to the log
            syncFun = 'teSyncEEG_fieldtrip';
            teEcho('tepInspect_fieldtrip: detected normal event relay.\n');
            
        end
            
%     try
        md.sync = struct;
        [md.sync.fieldtrip, tracker] =...
            feval(syncFun, tracker, tmp.ft_data, varargin{:});
%             teSyncEEG_fieldtrip(tracker, tmp.ft_data, varargin{:});
%     catch ERR
%         md.tepInspect_fieldtrip.success = false;
%         md.tepInspect_fieldtrip.outcome =...
%             sprintf('Error syncing fieldtrip: %s', ERR.message);
%         return
%     end
    
%     % correct from light sensor markers, if present
%     light = eegFT_matchLightSensorEvents(tmp.ft_data, 1000);
%     if light.found
%         
%         % log details
%         md.lightSensor.lightSensorChannelFound = true;
%         md.lightSensor.numLightMarkers = light.summary.numLightMarkers;
%         md.lightSensor.numMatchedLightMarkers = light.summary.numMatchedLightMarkers;
%         md.lightSensor.error_mu = light.summary.error_mu;
%         md.lightSensor.error_sd = light.summary.error_sd;
%         md.lightSensor.channel_label = light.lightChannelLabel;
%         md.lightSensor.channel_idx = find(light.lightChannelIdx);
%         
%         % correct
%         ft_data = eegFT_correctFromLightSensor(tmp.ft_data, light);
%         md.lightSensor.corrected = true;
%         save(ext.Paths('fieldtrip'), 'ft_data');
%         teEcho('Corrected fieldtrip event markers using light sensor.\n');
%         
%     else
%         md.lightSensor.channelFound = false;
%         md.lightSensor.corrected = false;
%     end
    
    md.tepInspect_fieldtrip.success = true;
    md.tepInspect_fieldtrip.outcome = 'success';

end