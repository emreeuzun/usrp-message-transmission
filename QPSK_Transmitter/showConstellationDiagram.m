%% Constellation Diagram Function
function showConstellationDiagram(receivedSymbols, title_str)
    % Create constellation diagram for QPSK symbols
    
    if nargin < 2
        title_str = 'QPSK Constellation Diagram';
    end
    
    % Create figure
    figure('Name', 'Constellation Diagram', 'NumberTitle', 'off');
    
    % Plot received symbols
    scatter(real(receivedSymbols), imag(receivedSymbols), 20, 'blue', 'filled', 'Alpha', 0.6);
    hold on;
    
    % Plot ideal QPSK constellation points
    ideal_points = [1+1j, -1+1j, -1-1j, 1-1j] * exp(1j*pi/4); % Phase offset pi/4
    scatter(real(ideal_points), imag(ideal_points), 100, 'red', 'x', 'LineWidth', 3);
    
    % Formatting
    grid on;
    axis equal;
    xlabel('In-Phase (I)');
    ylabel('Quadrature (Q)');
    title(title_str);
    legend('Received Symbols', 'Ideal QPSK Points', 'Location', 'best');
    
    % Add circles around ideal points to show decision regions
    theta = linspace(0, 2*pi, 100);
    radius = 0.5; % Adjust based on your system
    for i = 1:length(ideal_points)
        circle_x = real(ideal_points(i)) + radius * cos(theta);
        circle_y = imag(ideal_points(i)) + radius * sin(theta);
        plot(circle_x, circle_y, 'r--', 'Alpha', 0.3);
    end
    
    hold off;
end
