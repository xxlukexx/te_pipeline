function tepPlotSessionSummary(varargin)

    if length(varargin) == 1 && isa(varargin{1}, 'teSession')
        ses = varargin{1};
    elseif length(varargin) == 1 && ischar(varargin{1})
        try
            ses = teSession(varargin{1});
        catch ERR
            error('Error reading input argument as a path to a session: %s',...
                ERR.message)
        end
    end
    
    events = ses.Log.Events;
    firstTimestamp = events.timestamp(1);
    lastTimestamp = events.timestamp(end);
    sessionName = sprintf('%s_', ses.DynamicValues{:});
    sessionName(end) = [];
    
    fig = figure('name', sessionName, 'ToolBar', 'none', 'MenuBar', 'none');
    
    %%
    clf
    ax = axes(fig);
    xlim([firstTimestamp, lastTimestamp])

    ax.XTickLabel = [];
    dt = datetime(ax.XTick, 'ConvertFrom', 'posixtime');
    tf = datestr((ax.XTick - ax.XLim(1)) / 86400, 'HH:MM:SS.fff');
    cnt = 1;
    for i = ax.XTick
        lab = {i; char(dt(cnt)); tf(cnt, :)};
        text(i, ax.YLim(1), lab, 'horizontalalignment', 'center',...
            'verticalalignment', 'top')
        cnt = cnt + 1;
    end
        
    ax.YAxis.Visible = 'on';
    ax.Box = 'off';
    
    % set up y pos
    y = 100;
    col_sr = 'r';
    
    % screen recording
    sr = ses.ExternalData('screenrecording');
    if isempty(sr) || ~sr.Valid
        warning('Screen recording missing on invalid, not displaying.')
    end
    if ~isprop(sr, 'Sync') || isempty(sr.Sync)
        warning('Screen recording sync structure missing, not displaying.')
    end
    rectangle(...
        'position', [sr.Sync.teTime(1), y - 90, sr.Sync.teTime(2), y - 10],...
        'FaceColor', col_sr)
%     text(ax.XLim(1), y, 'Screen Recording', 'HorizontalAlignment', 'right')
    
    
    
    
    ylim([0, y + 100])

end