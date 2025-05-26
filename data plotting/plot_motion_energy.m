function plot_motion_energy(motion_energy_group, sampling_rate_group, avg_block)
   
    figure;
    hold on;

    numTraces = length(motion_energy_group);

    for m = 1:numTraces
        sampling_rate = sampling_rate_group{m};

        dt = avg_block / sampling_rate;  % intervalle entre deux points (en secondes)

        energy = motion_energy_group{m};
        if isempty(energy)
            continue;
        end

        % Axe X en secondes
        t = (0:length(energy)-1) * dt;
        plot(t, energy, 'DisplayName', sprintf('Session %d', m));
    end

    title('Motion Energy (Downsampled)');
    xlabel('Time (s)');
    ylabel('Normalized Energy');
    grid on;
    legend show;
    hold off;
end
