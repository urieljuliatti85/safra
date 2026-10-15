# Ícones SVG em traço único (1,75px, currentColor), desenhados para o Safra.
module IconHelper
  PATHS = {
    chevron_left: '<path d="m15 18-6-6 6-6"/>',
    chevron_right: '<path d="m9 18 6-6-6-6"/>',
    alert: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    copy: '<rect width="14" height="14" x="8" y="8" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
    printer: '<path d="M6 9V2h12v7"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><path d="M6 14h12v8H6z"/>',
    send: '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
    plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
    info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>'
  }.freeze

  def icon(name, label: nil, **options)
    attrs = { class: "icon", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": "1.75",
              "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": label ? nil : "true",
              role: label ? "img" : nil, "aria-label": label }.merge(options)
    content_tag(:svg, PATHS.fetch(name).html_safe, attrs.compact)
  end

  # Marca do Safra: dois brotos de folha.
  def brand_mark
    content_tag(:svg, '<path d="M12 21v-9"/><path d="M12 12c0-4 3-7 8-7 0 5-3 8-8 8Z"/><path d="M12 15c0-3-2-5-6-5 0 4 2 6 6 6Z"/>'.html_safe,
                class: "icon", style: "width:1.5rem;height:1.5rem", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
                "stroke-width": "2", "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": "true")
  end
end
