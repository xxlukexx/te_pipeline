function teSyncEEG_fieldtrip_plotMatch(e, s1, matchedLogIdx_te, lg, time_eeg, codes_eeg, lab_eeg, offset, path_out, reason_match)

    tryToMakePath(path_out)

    % get current te event, and events either side
    
        time_te = lg.timestamp;

        % find eeg timestamps, add tolerance window, and shift by
        % offset to convert to te time
        tolerance = 10;
        t1 = time_eeg(e) - tolerance - offset;
        t2 = time_eeg(e) + tolerance - offset;

        % check t1 is within bounds of te timestamps
        if t1 > time_te(end)
    %         reason_match{e, p} = 'EEG timestamp beyond bounds of Task Engine events';
            return
        end

        % convert timestamps to log item indices. Here we convert
        % timestamps to indices within the log, in the next step we
        % will extract all log items (te events) within the window
        % defined by s1:s2
        idx_match = find(lg.logIdx == matchedLogIdx_te);
        s1 = idx_match - 10;
        if s1 < 1, s1 = 1; end
        s2 = idx_match + 9;
        if s2 > size(lg, 1), s2 = size(lg, 1); end
%         s1 = s1 - 1 + find(time_te(s1:end) >= t1, 1, 'first');
%         s2 = s1 - 1 + find(time_te(s1:end) >= t2, 1, 'first');

            % if s2 not found, set it to s1
            if isempty(s2), s2 = s1; end

        % get event and timestamp for candidate te events (within
        % tolerance window)
        event_te = lg.data(s1:s2);
        eventTime_te = lg.timestamp(s1:s2);
        idx_subMatch = find(lg.logIdx(s1:s2) == matchedLogIdx_te, 1);
        
    % get current EEG event, and events either side
    
        s1 = e - 10;
        if s1 < 1, s1 = 1; end
        s2 = e + 9;
        if s2 > length(lab_eeg), s2 = length(lab_eeg); end
        
%         s1 = find(time_eeg >= t1, 1);
%         s2 = find(time_eeg >= t2, 1, 'first');
        numEEG = s2 - s1 + 1;
        
    % plot
    %%
    fig = figure('visible', 'off');
    fig.Position(4) = 1000;
    hold on
    xlim([0, 3])
    cols = lines(2);
    set(gca, 'ydir', 'reverse')
    
        % te
        scatter(ones(length(event_te), 1), eventTime_te, 60, 'MarkerFaceColor', cols(1, :))
        for i = 1:length(event_te)
            x = 0.8;
            y = eventTime_te(i);
            if isnumeric(event_te{i})
                event_te{i} = num2str(event_te{i});
            end
            t = text(x, y, event_te{i});
            t.Color = 'k';
            t.Interpreter = 'none';
            t.HorizontalAlignment = 'right';
            if i == idx_subMatch
                t.EdgeColor = cols(1, :);
                t.FontWeight = 'bold';
                t.LineWidth = 2;
                t.BackgroundColor = 'w';
                t.Tag = 'front';
            else
                t.EdgeColor = 'k';
                t.LineWidth = 1;
            end
        end
        
        % eeg
        scatter(repmat(2, s2 - s1 + 1, 1), time_eeg(s1:s2), 60, 'MarkerFaceColor', cols(2, :))
        for i = s1:s2
            x = 2.2;
            y = time_eeg(i);
%             y = time_eeg(s1 + i - 1);
            if isempty(lab_eeg{i})
                lab_eeg{i} = num2str(codes_eeg(i));
            end
            t = text(x, y, lab_eeg{i});
            t.Color = 'k';
            t.Interpreter = 'none';
            t.LineWidth = 1;            
            if i == s1 + 10
                t.EdgeColor = cols(2, :);
                t.FontWeight = 'bold';
                t.LineWidth = 2;
                t.BackgroundColor = 'w';
                t.Tag = 'front';
            else
                t.EdgeColor = 'k';
                t.LineWidth = 1;
            end
        end
        
        x1 = 1;
        x2 = 2;
        y1 = eventTime_te(idx_subMatch);
        y2 = time_eeg(e);
        t_err = time_eeg(e) - eventTime_te(idx_subMatch);
        l = line([x1, x2], [y1, y2]);
        l.Color = 'g';
        t = text(x1 + ((x2 - x1) / 2), y1, sprintf('%.1fms', t_err * 1000));
        t.Color = 'k';
        t.HorizontalAlignment = 'center';
        t.VerticalAlignment = 'bottom';
        
        % remove axes
        axis off
        set(gcf, 'Color', 'w')
        
        % sort z-order
        ch = get(gca, 'Children');
        idx_front = arrayfun(@(x) strcmpi(x.Tag, 'front'), ch);
        ch = [ch(idx_front); ch(~idx_front)];
        set(gca, 'Children', ch)
        if isempty(reason_match)
            reason_match = 'success';
        end
        title(reason_match)
        
        
        filename_out = sprintf('eegsync_%05d_%s.png', e, reason_match);
        file_out = fullfile(path_out, filename_out);
        exportgraphics(fig, file_out);
        delete(fig)

end