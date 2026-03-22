function plot_gcamp_histograms(results_analysis, gcamp_output_folders)

numFolders = length(results_analysis);

for m = 1:numFolders
    
    %==================== DATA ====================%
    freq = results_analysis(m).FrequencyPerCell_gcamp;
    freq = freq(isfinite(freq));
    
    dur = results_analysis(m).DurationPerCell_gcamp_s;
    dur = dur(isfinite(dur));
    
    iei = results_analysis(m).IEImeanPerCell_gcamp_s;
    iei = iei(isfinite(iei));
    
    %==================== CHECK DATA ====================%
    if isempty(freq) && isempty(dur) && isempty(iei)
        fprintf('m=%d: aucune donnée valide pour les histogrammes GCaMP. Skip.\n', m);
        continue;
    end
    
    %==================== OUTPUT ====================%
    output_folder = gcamp_output_folders{m};
    
    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end
    
    filename = fullfile(output_folder, sprintf('GCaMP_histograms_%s_%s.png', ...
        results_analysis(m).current_animal_group, ...
        results_analysis(m).Age));
    
    if exist(filename, 'file')
        fprintf('La figure "%s" existe déjà. Passage au suivant.\n', filename);
        continue;
    end
    
    %==================== FIGURE ====================%
    fig = figure('Position',[100 100 1200 400]);
    
    sgtitle(sprintf('GCaMP – %s %s', ...
        results_analysis(m).current_animal_group, ...
        results_analysis(m).Age));
    
    %----------- SUBPLOT 1 : FREQUENCY -----------%
    subplot(1,3,1)
    if isempty(freq)
        text(0.5, 0.5, 'Aucune donnée valide', 'HorizontalAlignment', 'center');
        axis off;
    else
        histogram(freq, 'BinMethod','fd');
        xlabel('Frequency (events / min)');
        ylabel('Number of cells');
        title('Frequency');
        grid on;
    end
    
    %----------- SUBPLOT 2 : DURATION -----------%
    subplot(1,3,2)
    if isempty(dur)
        text(0.5, 0.5, 'Aucune donnée valide', 'HorizontalAlignment', 'center');
        axis off;
    else
        histogram(dur, 'BinMethod','fd');
        xlabel('Transient duration (s)');
        ylabel('Number of cells');
        title('Duration');
        grid on;
    end
    
    %----------- SUBPLOT 3 : IEI -----------%
    subplot(1,3,3)
    if isempty(iei)
        text(0.5, 0.5, 'Aucune donnée valide', 'HorizontalAlignment', 'center');
        axis off;
    else
        histogram(iei, 'BinMethod','fd');
        xlabel('Mean inter-event interval (s)');
        ylabel('Number of cells');
        title('IEI');
        grid on;
    end
    
    %==================== SAVE ====================%
    saveas(fig, filename);
    close(fig);
    
    fprintf('Saved: %s\n', filename);
end

end