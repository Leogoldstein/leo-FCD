function [deviation, bad_frames, bad_frames_no_movement, bad_frames_with_movement, F] = ...
    motion_correction_substraction(F, ops, speed)

    corrXY = ops.corrXY(:);   % force colonne
    speed  = speed(:);        % force colonne

    % Sécurité longueur
    N = numel(corrXY);
    speed = speed(1:min(end,N));
    if numel(speed) < N
        speed(end+1:N) = speed(end);
    end

    % --- Déviation par rapport à la tendance locale ---
    rolling_median = movmedian(corrXY, 300);
    deviation = corrXY - rolling_median;

    % --- Bad frames (déviation négative forte) ---
    sigma_dev = std(deviation(deviation < 0));
    seuil_bad = -3 * sigma_dev;

    bad_frames = deviation < seuil_bad;

    % élargir d'une frame avant/après
    bad_frames = conv(double(bad_frames), [1 1 1], 'same') > 0;

    % --- Séparation avec / sans mouvement ---
    % Ici : speed < 1 = repos (comme ton code initial)
    bad_frames_no_movement   = bad_frames & (speed < 1);
    bad_frames_with_movement = bad_frames & (speed >= 1);

    % --- Logs ---
    fprintf('Bad frames total : %d (%.2f%%)\n', ...
        sum(bad_frames), 100*sum(bad_frames)/N);

    fprintf('Bad frames SANS mouvement (speed < 1) : %d (%.2f%%)\n', ...
        sum(bad_frames_no_movement), 100*sum(bad_frames_no_movement)/N);

    fprintf('Bad frames AVEC mouvement (speed >= 1) : %d (%.2f%%)\n', ...
        sum(bad_frames_with_movement), 100*sum(bad_frames_with_movement)/N);

    F_clean = F;
    F_clean(:, bad_frames) = NaN;
    F_clean = fillmissing(F_clean, 'linear', 2, 'EndValues', 'nearest'); %interpolation
    F = F_clean;

end