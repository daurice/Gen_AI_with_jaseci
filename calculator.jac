walker calculator {
    has float num1;
    has float num2;
    has str op;

    can run {
        if op == "+" {
            print("Result:", num1 + num2);
        }
        else if op == "-" {
            print("Result:", num1 - num2);
        }
        else if op == "*" {
            print("Result:", num1 * num2);
        }
        else if op == "/" {
            if num2 != 0 {
                print("Result:", num1 / num2);
            }
            else {
                print("Error: Division by zero!");
            }
        }
        else {
            print("Invalid operation!");
        }
    }
}
