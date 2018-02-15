require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def save_statistics(phone_book, hour, weekday)
  Dir.mkdir('statistics') unless Dir.exist? 'statistics'
  filename = 'statistics/stats.txt'
  hour = peak_hour?(hour)
  weekday = peak_weekday?(weekday)

  File.open(filename, 'w') do |file|
    file.puts "Peak hours are around: #{hour}"
    file.puts "Peak day is: #{weekday}"
    file.puts 'Phone book with associated names:'

    phone_book.each  do |x, y|
      file.puts "#{x} : #{y}"
    end
  end
end

def add_phone_number(number, name, book)
  book[name] = number
end

def clean_phone_numbers(number)
  number = number.to_s
  number = number.tr('^0-9', '')
  if number.length == 10
    pretty_number(number)
  elsif number.length == 11 && number[0] == '1'
    pretty_number(number[1..10])
  else
    '000-000-0000'
  end
end

def pretty_number(number)
  number[0..2] + '-' + number[3..5] + '-' + number[6..9]
end

def clean_zipcodes(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]  #-> Short version

end

def save_letter(id, letter)
  Dir.mkdir('output') unless Dir.exist? 'output'

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts letter
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def reg_date_and_time(date, ranking1, ranking2)
  fixed_date = DateTime.strptime(date, '%m/%d/%Y %H:%M')
  rank_hours(fixed_date.hour, ranking1)
  rank_weekday(fixed_date.wday, ranking2)
end

def rank_hours(hour, ranking)
  ranking[hour] += 1
end

def rank_weekday(day, ranking)
  name_of_day = ''
  case day
  when 0
    name_of_day = 'Monday'
  when 1
    name_of_day = 'Tuesday'
  when 2
    name_of_day = 'Wednesday'
  when 3
    name_of_day = 'Thursday'
  when 4
    name_of_day = 'Friday'
  when 5
    name_of_day = 'Saturday'
  when 6
    name_of_day = 'Sunday'
  end
  ranking[name_of_day] += 1
end

def peak_weekday?(ranking)
  max = ranking.max_by { |_k, v| v }
  max[0]
end

def peak_hour?(ranking)
  max = ranking.max_by { |_k, v| v }
  max[0]
end

puts 'EventManager Initialized!'

ranking_hours = Hash.new(0)
ranking_days = Hash.new(0)
phone_numbers = {}

lines = CSV.open 'event_attendees.csv', headers: true, header_converters: :symbol

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

lines.each do |row|
  id = row[0]
  name = row[:first_name]
  reg_date_and_time(row[1], ranking_hours, ranking_days)
  phone = clean_phone_numbers(row[5])
  add_phone_number(phone, name, phone_numbers)
  zipcode = clean_zipcodes(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_letter(id, form_letter)

end

save_statistics(phone_numbers, ranking_hours, ranking_days)
