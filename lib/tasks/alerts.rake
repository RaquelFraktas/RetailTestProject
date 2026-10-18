namespace :alerts do
  desc "Create out-of-stock alerts from existing tracking events (safe to re-run)"
  task detect: :environment do
    puts "Detecting out-of-stock alerts..."
    Alerts::OutOfStockDetector.new.call
    puts "Done. #{Alert.count} alerts."
  end
end
