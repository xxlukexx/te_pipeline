function md = tepInspect_tasks(tracker, md)

    md.tasks = struct;
    lg = teLog(tracker.Log);
    numTasks = length(lg.Tasks);
    for t = 1:numTasks
        md.tasks.(lg.Tasks{t}) = lg.TaskTrialSummary.Number(t);
    end

end