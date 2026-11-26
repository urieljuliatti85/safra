namespace :products do
  desc "Configure rounding for existing products (0=whole_box, 1=fraction)"
  task :set_rounding, [ :product_id, :rounding ] => :environment do |t, args|
    company = Company.first
    raise "Nenhuma empresa encontrada" unless company

    ActsAsTenant.with_tenant(company) do
      if args[:product_id] && args[:rounding]
        product = Product.find(args[:product_id])
        rounding = args[:rounding].to_i
        product.update!(rounding: rounding)
        puts "✅ #{product.name}: rounding = #{rounding} (#{Product::ROUNDINGS.key(rounding)})"
        next
      end

      # Interactive mode
      puts "Produtos atuais:"
      Product.order(:name).each do |p|
        label = Product::ROUNDINGS.key(p.rounding) || "unknown"
        puts "  #{p.id}: #{p.name} → #{p.rounding} (#{label})"
      end

      puts "\nUso: bin/rails products:set_rounding[ID,0|1]"
      puts "  0 = whole_box (caixa inteira - default)"
      puts "  1 = fraction  (fracionado)"
    end
  end

  desc "Set all raw materials (product_group=raw) to fraction rounding (fracionado)"
  task raw_materials_to_fraction: :environment do
    company = Company.first
    raise "Nenhuma empresa encontrada" unless company

    ActsAsTenant.with_tenant(company) do
      Product.where(product_group: "raw").find_each do |p|
        p.update!(rounding: Product::ROUNDINGS[:fraction])
        puts "✅ #{p.name}: fraction"
      end
      puts "Done."
    end
  end

  desc "Set all products to whole_box rounding (caixa inteira)"
  task all_to_whole_box: :environment do
    company = Company.first
    raise "Nenhuma empresa encontrada" unless company

    ActsAsTenant.with_tenant(company) do
      Product.update_all(rounding: Product::ROUNDINGS[:whole_box])
      puts "All products set to whole_box (0)."
    end
  end
end
