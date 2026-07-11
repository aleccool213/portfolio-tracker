module SparklineHelper
  # Map chronological amounts to SVG polyline points inside a width×height box.
  # Returns [] when fewer than two values (nothing useful to draw).
  def sparkline_points(amounts, width: 80, height: 28, pad: 2)
    values = Array(amounts).map { |a| a.to_f }
    return [] if values.size < 2

    min = values.min
    max = values.max
    span = max - min
    span = 1.0 if span.zero?

    inner_w = width - (pad * 2)
    inner_h = height - (pad * 2)
    step = values.size == 1 ? 0 : inner_w.to_f / (values.size - 1)

    values.each_with_index.map do |value, i|
      x = pad + (i * step)
      # SVG y grows downward; higher values sit higher on the chart.
      y = pad + inner_h - ((value - min) / span * inner_h)
      format("%.1f,%.1f", x, y)
    end
  end
end
