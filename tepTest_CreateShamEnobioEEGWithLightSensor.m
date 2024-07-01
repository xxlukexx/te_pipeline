function tracker = tepTest_CreateShamEnobioEEGWithLightSensor(path_out, numTrials,...
    idx_lightChan, delay_mu, delay_sd, fs)
% creates a fake enobio file containing light sensor pulses and associated
% EEG event markers. Both an enobio file and a te2 session are produced.
%
% delay_mu - the mean delay
% delay_sd - the SD of the delay
%
% a gaussian distribution is built from delay_mu and delay_sd. 

    % check input args
    
        if ~exist('idx_lightChan', 'var') || isempty(idx_lightChan)
            idx_lightChan = 1;
        end

        if ~exist('numTrials', 'var') || isempty(numTrials)
            numTrials = 10;
        end

        if ~exist('delay_mu', 'var') || isempty(delay_mu)
            delay_mu = 0.040;   % 40ms
        end

        if ~exist('delay_sd', 'var') || isempty(delay_sd)
            delay_sd = 0.016; 
        end

        if ~exist('fs', 'var') || isempty(fs)
            fs = 500;           % 500Hz
        end
        
    % set params

        % build distribution
        pd = makedist('normal', 'mu', delay_mu, 'sigma', delay_sd);
        delay = arrayfun(@(x) pd.random, 1:numTrials);

        % set duration of pulse, and inter-trial-interval
        dur = 0.500;
        iti = 1.000;

        % get onset of each pulse, and onset (with delay) or the marker
        firstTrialOffset = 1.000;
        trialDur = dur + iti;
        onset_pulse = firstTrialOffset:trialDur:numTrials * trialDur;
        onset_mrk = onset_pulse - delay;
        totalDur = firstTrialOffset + onset_pulse(end) + dur + iti + firstTrialOffset;

        % convert times to samples
        onset_pulse_samps = round(onset_pulse * fs);
        onset_mrk_samps = round(onset_mrk * fs);
        dur_pulse_samps = round(dur * fs);
        totalSamps = round(totalDur * fs);

        % calculate posix timestamps in milliseconds
        idx_samp = 1:totalSamps;
        posix_t = (teGetSecs + (idx_samp * (1 / fs))) * 1000;
    
        % make enobio file
        eeg(:, 1) = repmat(-400000047, totalSamps, 1);       % light sensor
        eeg(:, 2:4) = zeros(totalSamps, 3);                  % empty acc
        eeg(:, 5) = zeros(totalSamps, 1);                    % marker
        eeg(onset_mrk_samps, 5) = ones(numTrials, 1);
        eeg(:, 6) = posix_t;
        
        % make fake light sensor pulses (note enobio voltages are nV, i.e.
        % 10^-9 volts)
        for t = 1:numTrials    
            s1 = onset_pulse_samps(t);
            s2 = s1 + dur_pulse_samps - 1;
            eeg(s1:s2, 1) = repmat(5 * 10e-9, dur_pulse_samps, 1);
        end
        
    % prepare info file template
    
        % attempt to find info template file
        file_template = 'enobio_template.info';
        if ~exist(file_template, 'file')
            error('Cannot find the info template file ''enobio_template.info''.')
        end
        temp = fileread(file_template);
        
        temp = strrep(temp, '#first_posix#', num2str(round(posix_t(1))));        
        temp = strrep(temp, '#first_sample#', num2str(idx_samp(end)));
        temp = strrep(temp, '#fs#', num2str(fs));
        temp = strrep(temp, '#total_duration#', num2str(round(totalDur)));
        
    % prepare log
    
        
        
    % prepare tracker
        
        tracker = teTracker;
        tracker.Path_Root = path_out;
        tracker.AddVariable('name', 'ID', 'makeSubFolders', true)
        tracker.ID = 'SHAM';
        % add log here
        tracker.Save
        
    % write enobio output
    
        path_enobio = fullfile(tracker.Path_Session, 'enobio');
        tryToMakePath(path_enobio);
        file_easy = fullfile(path_enobio, sprintf('%s.easy', tracker.ID));
        file_info = fullfile(path_enobio, sprintf('%s.info', tracker.ID));
        
        % write new info file
        teEcho('Saving .info file to: %s\n', file_info);
        fid = fopen(file_info, 'w+');
        fprintf(fid, '%s', temp);
        fclose(fid);
    
        % write new easy file
        teEcho('Saving .easy file to: %s\n', file_easy);
        writetable(array2table(eeg), file_easy, 'WriteVariableNames', false, 'FileType', 'text')
        

end



