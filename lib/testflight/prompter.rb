#--
# Copyright (c) 2012 Michael Berkovich
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

module Testflight
  class Prompter

    def self.read_options(question=nil, opts=["Yes", "No"], vals=["y", "yes", "n", "no"], joiner = "/")
      prompt = "(#{opts.join(joiner)})? "
      pp question if question
      
      $stdout.print(prompt)
      
      $stdin.each_line do |line|
        value = line.strip.downcase
        return value if vals.include?(value)
        $stdout.print(prompt)
      end  
    end

    def self.read_info(question=nil, prompt="> ", allow_blank=false)
      pp question if question
      
      $stdout.print(prompt)
      
      $stdin.each_line do |line|
        value = line.strip.downcase
        return value if allow_blank 
        return value unless value.empty?
        $stdout.print(prompt)
      end  
    end

    def self.read_set_values(opts)
      lists = []
      vals = read_info(nil, prompt="? ") 
      vals.split(",").each do |index|
        index = index.to_i - 1
        return nil if index<0 or index>=opts.size
        lists << opts[index]
      end
      lists
    end 

    def self.select_set(question, opts = [])
      pp question

      opts.each_with_index do |opt, index|
        pp "    #{index+1}) #{opt}"
      end
      
      vals = read_set_values(opts)
      while vals.nil?
        pp "Invalid selection, please try again."
        vals = read_set_values(opts)
      end
      
      vals
    end

  end
end