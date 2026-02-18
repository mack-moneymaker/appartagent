module ApplicationHelper
  def score_badge(score)
    return "" if score.blank?

    score = score.to_i
    if score >= 80
      label, color = "Excellent", "green"
    elsif score >= 60
      label, color = "Bon", "blue"
    elsif score >= 40
      label, color = "Moyen", "yellow"
    else
      label, color = "À éviter", "red"
    end

    content_tag(:span, "#{score} — #{label}",
      class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-#{color}-100 text-#{color}-800")
  end

  def score_color(score)
    return "gray" if score.blank?
    score = score.to_i
    if score >= 80 then "green"
    elsif score >= 60 then "blue"
    elsif score >= 40 then "yellow"
    else "red"
    end
  end
end
