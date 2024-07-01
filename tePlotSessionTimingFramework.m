function tePlotSessionTimingFramework(tab_all)
    % Create a figure
    fig = figure('Color', [.15, .15, .20], 'MenuBar', 'none');

    % Find unique data types and sessions
    data_types = unique(tab_all.result);
    sessions = unique(tab_all.session);

    % Assign unique colors for each data type
    colors = lines(length(data_types));
    color_map = containers.Map(data_types, num2cell(colors, 2));

    % Plot rectangles for each data type
    hold on;
    for i = 1:height(tab_all)
        % Determine the y-axis position based on data type and session
        type_idx = find(strcmp(data_types, tab_all.result{i}));
        session_idx = find(sessions == tab_all.session(i));
        total_sessions = length(sessions);
        
        % Calculate height and y-position for the rectangle
        rect_height = 0.8 / total_sessions;
        y = type_idx - 0.4 + (session_idx - 1) * rect_height;

        % Determine the width of the rectangle
        width = tab_all.t2(i) - tab_all.t1(i);

        % Determine the color for the data type
        color = color_map(tab_all.result{i});

        % Plot the rectangle
        rect = rectangle('Position', [tab_all.t1(i), y, width, rect_height], 'FaceColor', color, 'EdgeColor', 'none');

        % Add session number text
        text(tab_all.t1(i) + width/2, y + rect_height/2, ['Session ' num2str(tab_all.session(i))], 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Color', 'white');
    end
    hold off;

    % Adjust axes
    xlim([min(tab_all.t1) * .9999999, max(tab_all.t2)]);
    ylim([0, length(data_types) + 1]);
    set(gca, 'YTick', [], 'XTick', [], 'Color', [.15, .15, .20], 'XColor', 'none', 'YColor', 'none');

    % Add rotated text labels for each data type
    for y = 1:length(data_types)
        text(min(tab_all.t1) * .9999999, y, data_types{y}, 'Rotation', 90, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'Color', 'white', 'FontWeight', 'bold', 'FontSize', 16);
    end
end
